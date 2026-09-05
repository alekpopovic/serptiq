# frozen_string_literal: true

require "test_helper"

class CrawlingScanUsageAccountingTest < ActiveSupport::TestCase
  class NullDispatch
    def call(**)
      true
    end
  end

  class NullUsageFinalizer
    def call_locked(**)
      true
    end
  end

  setup do
    Current.reset
    sync_usage_catalog
    @now = Time.current.change(usec: 0) - 1.hour
    @owner, @authorization = create_subscribed_usage_organization(
      plan_key: "starter", slug: "scan-usage-accounting"
    )
    enable_project_limit(@owner, at: @now)
    enable_property_limits(@owner, at: @now)
    enable_crawl_policy(
      @owner,
      values: { "crawl.concurrent_scans" => [ "integer", 2 ] },
      at: @now
    )
    @project = create_project_for(@owner, slug: "scan-usage-project", at: @now)
    @property = create_property_for(@owner, project: @project, at: @now)
    @environment = @property.environments.sole
    create_fresh_verification
    set_credit_limit(26)
    @scan = admit("usage-primary")
    run_scan_to(@scan, "running", at: @now + 1.second)
  end

  teardown { Current.reset }

  test "snapshot pins exact configured rates and operations finalize once by source key" do
    meters = @scan.entitlement_snapshot.dig("credit_estimate", "meters")
    assert_equal 1, @scan.entitlement_snapshot.dig("credit_estimate", "catalog_version")
    assert_match(/\A[0-9a-f]{64}\z/, @scan.entitlement_snapshot.dig("credit_estimate", "catalog_checksum"))
    assert_equal %w[crawl.http_fetch crawl.rendered_page performance.lighthouse_page], meters.keys.sort
    assert_equal "1.0", meters.dig("crawl.http_fetch", "weight")
    assert_equal "10.0", meters.dig("crawl.rendered_page", "weight")
    assert_equal "15.0", meters.dig("performance.lighthouse_page", "weight")
    assert meters.values.all? { |meter| Usage::MeterRate.exists?(meter.fetch("meter_rate_id")) }

    http = perform_operation("url-1:http:attempt-1", "http_fetch", "accepted")
    assert_equal http.id,
      perform_operation("url-1:http:attempt-1", "http_fetch", "accepted").id
    failed = perform_operation("url-2:http:attempt-1", "http_fetch", "failed")
    render = perform_operation("url-1:render:attempt-1", "rendered_page", "accepted")
    lighthouse = perform_operation("url-1:lighthouse:attempt-1", "lighthouse_page", "accepted")
    artifact = perform_operation("url-1:html:artifact-1", "artifact", "accepted")

    assert http.billed?
    assert failed.not_billable?
    assert render.billed?
    assert lighthouse.billed?
    assert artifact.not_billable?
    assert_equal 3, Usage::UsageEvent.where(event_kind: "usage").count
    assert_equal BigDecimal("26"), @scan.quota_reservation.reload.consumed_quantity
    assert_equal BigDecimal("26"), @scan.quota_reservation.held_quantity

    breakdown = Crawling::Public.scan_cost_breakdown(
      actor_membership: @owner.membership,
      project_id: @project.id,
      scan_id: @scan.id
    )
    assert_equal BigDecimal("26"), breakdown.gross_credits
    assert_equal BigDecimal("26"), breakdown.net_credits
    http_cost = breakdown.entries.find { |entry| entry.operation_kind == "http_fetch" }
    assert_equal 2, http_cost.attempt_count
    assert_equal 1, http_cost.billable_count
    assert_equal 1, http_cost.non_billable_count

    transition_scan(@scan, "complete", at: @now + 10.minutes)
    reservation = @scan.quota_reservation.reload
    assert reservation.finalized?
    assert_equal BigDecimal("0"), reservation.released_quantity
    summary = Usage::Public.summary(
      organization_id: @owner.organization.id,
      window_id: reservation.usage_window_id,
      at: @now + 11.minutes
    )
    assert_equal BigDecimal("26"), summary.used
    assert_equal BigDecimal("0"), summary.reserved
  end

  test "cancellation bills accepted responses and releases failed and abandoned attempts" do
    accepted = perform_operation("cancel:http:accepted", "http_fetch", "accepted")
    perform_operation("cancel:http:transport-failure", "http_fetch", "failed")
    pending = start_operation("cancel:render:worker-lost", "rendered_page")

    Crawling::Public.request_scan_cancellation(
      actor_membership: @owner.membership,
      project_id: @project.id,
      scan_id: @scan.id,
      clock: -> { @now + 5.minutes }
    )
    transition_scan(@scan, "acknowledge_cancel", at: @now + 6.minutes)

    assert_equal "canceled", @scan.reload.status
    assert accepted.reload.billed?
    assert_equal "abandoned", pending.reload.outcome
    assert pending.not_billable?
    assert pending.quota_allocation.released?
    reservation = @scan.quota_reservation.reload
    assert reservation.finalized?
    assert_equal BigDecimal("1"), reservation.consumed_quantity
    assert_equal BigDecimal("24"), reservation.released_quantity
    assert_equal 1, Usage::UsageEvent.where(event_kind: "usage").count

    assert_raises(Crawling::Conflict) do
      finish_operation("cancel:render:worker-lost", "accepted", at: @now + 7.minutes)
    end
  end

  test "quota exhaustion pauses before extra work and creates no attempt or charge" do
    6.times { |index| perform_operation("quota:http:#{index}", "http_fetch", "accepted") }
    2.times { |index| perform_operation("quota:render:#{index}", "rendered_page", "accepted") }
    before = [ Crawling::ScanUsageOperation.count, Usage::QuotaAllocation.count, Usage::UsageEvent.count ]

    error = assert_raises(Usage::QuotaExceeded) do
      start_operation("quota:http:beyond-estimate", "http_fetch")
    end

    assert_equal BigDecimal("1"), error.denial.requested
    assert_equal before,
      [ Crawling::ScanUsageOperation.count, Usage::QuotaAllocation.count, Usage::UsageEvent.count ]
    assert_equal "running", @scan.reload.status
    assert_equal "quota_exhausted", @scan.throttle_reason
    assert_equal error.denial.reset_at, @scan.throttle_until
  end

  test "terminal recovery releases crash remnants and finalizes exactly once" do
    pending = start_operation("recovery:http:pending", "http_fetch")
    transition = Crawling::TransitionScan.new(
      clock: -> { @now + 4.minutes },
      usage_finalizer: NullUsageFinalizer.new
    )
    transition.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      command: "fail",
      failure_category: "worker_lost"
    )
    assert @scan.reload.terminal?
    assert @scan.quota_reservation.reload.held?

    assert_equal 1, Crawling::Public.recover_terminal_scan_usage(clock: -> { @now + 5.minutes })
    assert_equal 0, Crawling::Public.recover_terminal_scan_usage(clock: -> { @now + 5.minutes })
    assert pending.reload.not_billable?
    assert_equal "abandoned", pending.outcome
    assert @scan.quota_reservation.reload.finalized?
    assert_equal BigDecimal("25"), @scan.quota_reservation.released_quantity
  end

  test "reservation expiry releases pending allocations without blocking later scan failure" do
    pending = start_operation("expiry:render:pending", "rendered_page")
    cutoff = @scan.quota_reservation.expires_at + 1.second

    result = Usage::Public.maintain_reservations(at: cutoff)
    assert_equal 1, result.expired_count
    assert @scan.quota_reservation.reload.expired?
    assert pending.quota_allocation.reload.released?

    Crawling::Public.transition_scan(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      command: "fail",
      failure_category: "quota_reservation_unavailable",
      clock: -> { cutoff + 1.second }
    )
    assert_equal "failed", @scan.reload.status
    assert_equal "abandoned", pending.reload.outcome
    assert pending.not_billable?
  end

  test "support correction is an audited compensating event and cross tenant access is denied" do
    operation = perform_operation("support:http:accepted", "http_fetch", "accepted")
    correction = Crawling::Public.adjust_scan_usage(
      organization_id: @owner.organization.id,
      scan_id: @scan.id,
      usage_event_id: operation.usage_event_id,
      actor_membership: @owner.membership,
      authorization: @authorization,
      idempotency_key: "support-correction-1",
      quantity: -1,
      reason_code: "duplicate_charge",
      occurred_at: @now + 5.minutes
    )

    assert_equal "correction", correction.event_kind
    assert_equal operation.usage_event_id, correction.correction_of_event_id
    assert Auditing::AuditEvent.exists?(
      action: "usage.corrected",
      target_id: @scan.id,
      actor_membership_id: @owner.membership.id
    )
    breakdown = Crawling::ScanCostQuery.new.build(@scan.reload)
    assert_equal BigDecimal("1"), breakdown.gross_credits
    assert_equal BigDecimal("0"), breakdown.net_credits

    foreign = create_organization_for(slug: "scan-usage-adjustment-foreign")
    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.adjust_scan_usage(
        organization_id: foreign.organization.id,
        scan_id: @scan.id,
        usage_event_id: operation.usage_event_id,
        actor_membership: foreign.membership,
        authorization: @authorization,
        idempotency_key: "support-cross-tenant",
        quantity: -1,
        reason_code: "duplicate_charge"
      )
    end
  end

  test "database and service boundaries reject cross-scan and cross-tenant substitution" do
    operation = start_operation("isolation:http:pending", "http_fetch")
    other_scan = create_scan_for(
      @owner,
      project: @project,
      property: @property,
      at: @now + 4.minutes
    )
    run_scan_to(other_scan, "running", at: @now + 4.minutes)
    allocation = operation.quota_allocation
    isolated_allocation = Usage::Public.allocate_reservation(
      clock: -> { @now + 5.minutes },
      organization_id: @scan.organization_id,
      reservation_id: @scan.usage_quota_reservation_id,
      idempotency_key: "isolation-cross-scan-allocation",
      window: allocation.window,
      meter_rate: allocation.meter_rate,
      quantity: 1,
      at: @now + 5.minutes
    )
    attributes = operation.attributes.except("id", "created_at", "updated_at").merge(
      "scan_id" => other_scan.id,
      "usage_quota_allocation_id" => isolated_allocation.id,
      "source_key_digest" => Digest::SHA256.hexdigest("isolation-cross-scan"),
      "request_checksum" => Digest::SHA256.hexdigest("isolation-cross-scan-request"),
      "attempted_at" => @now + 5.minutes,
      "created_at" => @now + 5.minutes,
      "updated_at" => @now + 5.minutes
    )
    assert_raises(ActiveRecord::StatementInvalid) do
      Crawling::ScanUsageOperation.transaction(requires_new: true) do
        Crawling::ScanUsageOperation.insert!(attributes)
      end
    end

    foreign = create_organization_for(slug: "scan-usage-operation-foreign")
    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.start_usage_operation(
        organization_id: foreign.organization.id,
        scan_id: @scan.id,
        source_key: "isolation-cross-tenant",
        operation_kind: "http_fetch",
        at: @now + 5.minutes
      )
    end
  end

  private

  def admit(key)
    command = Crawling::AdmissionRequest.new(
      idempotency_key: key,
      source: "manual",
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      scan_type: "full"
    )
    Crawling::AdmitScan.new(
      clock: -> { @now },
      preflight: ->(environment:) {
        Crawling::PreflightResult.new(
          checked_at: @now,
          status_code: 200,
          destination_digest: Digest::SHA256.hexdigest(environment.origin.origin),
          redirect_count: 0
        )
      },
      dispatch_enqueuer: NullDispatch.new
    ).call(actor_membership: @owner.membership, request: command)
  end

  def start_operation(source_key, kind, at: @now + 3.minutes)
    Crawling::Public.start_usage_operation(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      source_key: source_key,
      operation_kind: kind,
      at: at
    )
  end

  def finish_operation(source_key, outcome, at: @now + 3.minutes)
    Crawling::Public.finish_usage_operation(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      source_key: source_key,
      outcome: outcome,
      occurred_at: at,
      at: at
    )
  end

  def perform_operation(source_key, kind, outcome)
    start_operation(source_key, kind)
    finish_operation(source_key, outcome)
  end

  def create_fresh_verification
    Verification::Challenge.create!(
      organization_id: @owner.organization.id,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      issued_by_membership_id: @owner.membership.id,
      method: "dns_txt",
      challenge_digest: Digest::SHA256.hexdigest("scan-usage-proof"),
      expected_location: "_searchops.#{@environment.host}",
      bound_origin: @environment.origin,
      state: "verified",
      attempt_count: 0,
      verified_at: @now - 1.hour,
      expires_at: @now + 90.days,
      evidence: {},
      created_at: @now - 1.hour,
      updated_at: @now - 1.hour
    )
  end

  def set_credit_limit(value)
    definition = Entitlements::Definition.find_by!(key: "crawl.credits_monthly")
    Entitlements::OrganizationOverride.create!(
      organization_id: @owner.organization.id,
      entitlement_definition_id: definition.id,
      value_type: "integer",
      value: value,
      starts_at: @now - 1.minute,
      reason: "Scan usage boundary test",
      source: "support",
      created_by_membership_id: @owner.membership.id
    )
    Current.entitlement_cache = nil
  end
end
