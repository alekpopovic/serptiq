# frozen_string_literal: true

require "json"
require "test_helper"

class AuthorizationAccessBoundaryTest < ActiveSupport::TestCase
  class CaptureLogger
    attr_reader :entries

    def initialize
      @entries = []
    end

    %i[debug info warn error fatal].each do |severity|
      define_method(severity) { |message| entries << [ severity, message ] }
    end
  end

  setup do
    Current.reset
    sync_usage_catalog
    @owner, = create_subscribed_usage_organization(slug: "unified-access")
    @member = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Access Member")
    )
    @project_id = deterministic_uuid("project", "unified-access")
    Authorization::Public.register_scope(
      organization_id: @owner.organization.id,
      scope_type: "Project",
      scope_id: @project_id
    )
    @now = Time.current.change(usec: 0)
    @window = Usage::Public.resolve_window(
      organization_id: @owner.organization.id,
      meter_key: "crawl.http_fetch",
      at: @now,
      billing_period: Usage::BillingPeriod.new(
        starts_at: @now.beginning_of_month,
        ends_at: @now.next_month.beginning_of_month,
        time_zone_name: "UTC",
        reference: "unified-access-period"
      )
    )
    @source = usage_source(@owner, id: deterministic_uuid("scan", "unified-access"))
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
  end

  teardown do
    Shared::Observability.emitter = @previous_emitter
    Current.reset
  end

  test "access request requires a complete metered context and retains no inferred plan state" do
    request = metered_request(quantity: 3, key: "request-contract")

    assert_equal @owner.membership.id, request.actor_membership_id
    assert_equal "scans.run", request.permission_key
    assert_equal "crawl.manual", request.entitlement_key
    assert_equal 3, request.metered_quantity
    assert_equal "request-contract", request.idempotency_key
    assert request.metered?
    assert request.entitlement?
    assert_predicate request, :frozen?
    refute_respond_to request, :plan_name

    assert_raises(ArgumentError) do
      access_request(metered_quantity: 1, idempotency_key: "incomplete")
    end
  end

  test "truth table allows only after permission entitlement resource and quota all allow" do
    decision = Authorization::Public.access_decision(metered_request(quantity: 5, key: "all-allow"))

    assert decision.allow?
    assert_equal "allowed", decision.stage
    assert_equal "access_granted", decision.reason_code
    assert_nil decision.public_error_code
    assert_equal "permission_granted", decision.authorization.reason_code
    assert_equal "enabled", decision.entitlement.state
    assert decision.reserved?
    assert_equal BigDecimal("5"), decision.reservation.held_quantity
    assert_equal "atomic_usage_reservation", decision.provenance.fetch(:quota)
  end

  test "permission denial precedes entitlement resource and quota observations" do
    before = Usage::QuotaReservation.count
    decision = Authorization::Public.access_decision(metered_request(
      actor: @member,
      entitlement_key: "crawl.javascript_rendering",
      resource: resource(available: false),
      quantity: 1,
      key: "permission-denied"
    ))

    assert decision.deny?
    assert_equal "authorization", decision.stage
    assert_equal "permission_missing", decision.reason_code
    assert_equal "authorization_denied", decision.public_error_code
    assert_nil decision.entitlement
    assert_nil decision.quota_denial
    assert_equal before, Usage::QuotaReservation.count
  end

  test "authentication and active membership fail before all paid capability checks" do
    anonymous = Authorization::Public.access_decision(metered_request(
      actor: nil, quantity: 1, key: "anonymous-denied"
    ))
    assert_equal "authorization", anonymous.stage
    assert_equal "not_authenticated", anonymous.reason_code
    assert_equal "authentication_required", anonymous.public_error_code

    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership,
      target_membership_id: @member.id,
      operation: "suspend"
    )
    inactive = Authorization::Public.access_decision(metered_request(
      actor: @member, quantity: 1, key: "inactive-denied"
    ))
    assert_equal "authorization", inactive.stage
    assert_equal "membership_inactive", inactive.reason_code
    assert_equal "authorization_denied", inactive.public_error_code
    assert_equal 0, Usage::QuotaReservation.count
  end

  test "unmetered protected operation omits quota without weakening permission or entitlement" do
    decision = Authorization::Public.access_decision(access_request)

    assert decision.allow?
    refute decision.reserved?
    assert_equal "enabled", decision.entitlement.state
    assert_equal 0, Usage::QuotaReservation.count
  end

  test "disabled entitlement precedes invalid resource state and quota" do
    decision = Authorization::Public.access_decision(metered_request(
      entitlement_key: "crawl.javascript_rendering",
      resource: resource(available: false),
      quantity: 1,
      key: "entitlement-denied"
    ))

    assert decision.deny?
    assert_equal "entitlement", decision.stage
    assert_equal "entitlement_disabled", decision.reason_code
    assert_equal "entitlement_required", decision.public_error_code
    assert_equal 0, Usage::QuotaReservation.count
  end

  test "invalid resource state precedes quota and foreign linkage has a generic public denial" do
    unavailable = Authorization::Public.access_decision(metered_request(
      resource: resource(available: false), quantity: 1, key: "resource-unavailable"
    ))
    assert_equal "resource", unavailable.stage
    assert_equal "resource_unavailable", unavailable.reason_code
    assert_equal "resource_conflict", unavailable.public_error_code

    foreign = create_organization_for(slug: "unified-resource-foreign")
    mismatched = Authorization::Public.access_decision(metered_request(
      resource: resource(organization_id: foreign.organization.id),
      quantity: 1,
      key: "resource-foreign"
    ))
    assert_equal "resource", mismatched.stage
    assert_equal "scope_mismatch", mismatched.reason_code
    assert_equal "authorization_denied", mismatched.public_error_code
    assert_equal 0, Usage::QuotaReservation.count
  end

  test "quota exhaustion and capacity held elsewhere return quota denial without a charge" do
    held = Authorization::Public.access_decision(metered_request(
      quantity: 25_000, key: "hold-entire-pool"
    ))
    assert held.allow?

    denied = Authorization::Public.access_decision(metered_request(
      source: usage_source(@owner, id: deterministic_uuid("scan", "second-access")),
      quantity: 1,
      key: "held-elsewhere"
    ))

    assert denied.deny?
    assert_equal "quota", denied.stage
    assert_equal "usage_quota_exceeded", denied.reason_code
    assert_equal "quota_exceeded", denied.public_error_code
    assert_equal BigDecimal("25000"), denied.quota_denial.reserved
    assert_equal 1, Usage::QuotaReservation.count
    assert_equal 0, Usage::UsageEvent.count
  end

  test "retries reuse one reservation and never double charge" do
    request = metered_request(quantity: 7, key: "retry-access")

    first = Authorization::Public.access_decision(request)
    replay = Authorization::Public.access_decision(request)

    assert_equal first.reservation.id, replay.reservation.id
    assert_equal 1, Usage::QuotaReservation.count
    assert_equal 0, Usage::UsageEvent.count
  end

  test "enqueue exception releases reservation and preserves the original failure" do
    request = metered_request(quantity: 9, key: "enqueue-failure")

    error = assert_raises(RuntimeError) do
      Authorization::Public.with_access(request) { raise "queue rejected the job" }
    end

    assert_equal "queue rejected the job", error.message
    reservation = Usage::QuotaReservation.sole
    assert reservation.released?
    assert_equal BigDecimal("9"), reservation.released_quantity
    assert_equal 0, Usage::UsageEvent.count
    assert_equal [ "release" ], reservation.operations.pluck(:operation_kind)
  end

  test "cross tenant denial performs no downstream lookups and exposes no sensitive context" do
    foreign = create_organization_for(slug: "unified-access-foreign")
    calls = []
    boundary = Authorization::AccessBoundary.new(
      authorization: ->(request) { calls << :authorization; Authorization::Decision.new.call(request, validate_resource: false) },
      entitlement_resolver: ->(**) { calls << :entitlement; flunk("entitlement must not resolve") },
      quota_reserver: ->(**) { calls << :quota; flunk("quota must not reserve") }
    )
    request = Authorization::AccessRequest.new(
      actor_membership: foreign.membership,
      organization: @owner.organization,
      permission_key: "scans.run",
      project: @project_id,
      resource: resource(available: false),
      entitlement_key: "crawl.manual"
    )

    decision = boundary.call(request)

    assert_equal [ :authorization ], calls
    assert_equal "scope_mismatch", decision.reason_code
    assert_equal "authorization_denied", decision.public_error_code
    refute_includes JSON.generate(decision.provenance), foreign.organization.id
    assert_equal 0, Usage::QuotaReservation.count
  end

  test "enforcement raises category-specific public errors and job adapter reauthorizes context" do
    disabled = access_request(entitlement_key: "crawl.javascript_rendering")
    error = assert_raises(Entitlements::Public::Required) do
      Authorization::Public.authorize_access!(disabled)
    end
    assert_equal "entitlement_disabled", error.reason_code
    assert_equal "entitlement_required", error.definition.public_code

    yielded = nil
    result = Authorization::Public.authorize_job_access!(
      user_id: @owner.membership.user_id,
      organization_id: @owner.organization.id,
      permission_key: "scans.run",
      project: @project_id,
      entitlement_key: "crawl.manual"
    ) do |decision, membership, organization|
      yielded = [ decision.allow?, membership.id, organization.id ]
    end

    assert result.allow?
    assert_equal [ true, @owner.membership.id, @owner.organization.id ], yielded
    assert_nil Current.organization
  end

  test "access instrumentation uses bounded labels and never logs raw keys or resource identifiers" do
    raw_key = "private-command-key-#{SecureRandom.hex(12)}"
    resource_id = deterministic_uuid("scan", "instrumentation")
    Authorization::Public.access_decision(metered_request(
      resource: resource(id: resource_id), quantity: 1, key: raw_key
    ))

    records = @logger.entries.map { |entry| JSON.parse(entry.last) }
    access = records.select { |record| record.fetch("event_name").start_with?("access.") }
    assert_equal %w[access.decision_evaluated access.quota_reserved], access.map { |record| record.fetch("event_name") }
    assert access.all? { |record| record.fetch("operation") == "scans.run" }
    refute_includes access.to_json, raw_key
    refute_includes access.to_json, resource_id
    refute_includes access.to_json, @source.id
  end

  private

  def access_request(actor: @owner.membership, entitlement_key: "crawl.manual", resource: resource,
    **attributes)
    Authorization::AccessRequest.new(
      actor_membership: actor,
      organization: @owner.organization,
      permission_key: "scans.run",
      project: @project_id,
      resource: resource,
      entitlement_key: entitlement_key,
      **attributes
    )
  end

  def metered_request(quantity:, key:, actor: @owner.membership, entitlement_key: "crawl.manual",
    resource: resource, source: @source)
    access_request(
      actor: actor,
      entitlement_key: entitlement_key,
      resource: resource,
      metered_quantity: quantity,
      idempotency_key: key,
      usage_window: @window,
      usage_source: source,
      reservation_expires_at: @now + 1.hour,
      evaluated_at: @now
    )
  end

  def resource(id: deterministic_uuid("scan", "unified-resource"),
    organization_id: @owner.organization.id, available: true)
    Authorization::ResourceContext.new(
      id: id,
      type: "Scan",
      organization_id: organization_id,
      scope_type: "Project",
      scope_id: @project_id,
      available: available
    )
  end
end
