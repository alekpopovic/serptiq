# frozen_string_literal: true

require "test_helper"

class CrawlingScanAdmissionTest < ActiveSupport::TestCase
  class CapturingJob
    class << self
      attr_accessor :arguments, :failure

      def perform_later(**arguments)
        raise failure if failure

        self.arguments = arguments
      end
    end
  end

  setup do
    Current.reset
    sync_usage_catalog
    @now = Time.current.change(usec: 0)
    @owner, = create_subscribed_usage_organization(plan_key: "starter", slug: "scan-admission")
    enable_project_limit(@owner, at: @now)
    enable_property_limits(@owner, at: @now)
    enable_crawl_policy(
      @owner,
      values: { "crawl.concurrent_scans" => [ "integer", 1 ] },
      at: @now
    )
    @project = create_project_for(@owner, slug: "admission-project", at: @now)
    @property = create_property_for(@owner, project: @project, at: @now)
    @environment = @property.environments.sole
    @verification = create_fresh_verification(@owner, @project, @property, @environment, @now)
    @preflight = ->(environment:) {
      assert_equal @environment.id, environment.id
      Crawling::PreflightResult.new(
        checked_at: @now,
        status_code: 200,
        destination_digest: Digest::SHA256.hexdigest(environment.origin.origin),
        redirect_count: 0
      )
    }
    CapturingJob.arguments = nil
    CapturingJob.failure = nil
  end

  teardown do
    CapturingJob.arguments = nil
    CapturingJob.failure = nil
    Current.reset
  end

  test "request command supports schedule and release provenance with optional correlations" do
    baseline_id = SecureRandom.uuid
    release_id = SecureRandom.uuid
    request = Crawling::AdmissionRequest.new(
      idempotency_key: "release-command",
      source: "release",
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      scan_type: "targeted",
      baseline_scan_id: baseline_id,
      release_id: release_id
    )

    assert_equal "release", request.initiator_type
    assert_equal baseline_id, request.baseline_scan_id
    assert_equal release_id, request.release_id
    assert_match(/\A[0-9a-f]{64}\z/, request.idempotency_digest)
    assert_match(/\A[0-9a-f]{64}\z/, request.checksum)
  end

  test "admits one immutable request with a weighted quota hold and idempotent dispatch" do
    command = command_for("admission-one")
    scan = admit(command)

    assert_equal "admitted", scan.status
    assert_equal "manual", scan.request_source
    assert_equal command.idempotency_digest, scan.request_idempotency_digest
    assert_equal command.checksum, scan.request_checksum
    assert_equal @verification.id, scan.domain_verification_id
    assert_equal BigDecimal("25"), scan.credit_estimate
    assert_equal %w[scan.requested scan.admitted], scan.events.order(:sequence).pluck(:event_type)
    assert_equal 2, scan.progress_sequence
    assert_equal scan.id, CapturingJob.arguments.fetch(:scan_id)
    assert scan.reload.dispatch_enqueued_at

    reservation = scan.quota_reservation
    assert reservation.held?
    assert_equal scan.id, reservation.source_id
    assert_equal BigDecimal("25"), reservation.held_quantity
    assert_equal 1, Usage::QuotaReservation.count

    replay = admit(command)
    assert_equal scan.id, replay.id
    assert_equal 1, Crawling::Scan.count
    assert_equal 1, Usage::QuotaReservation.count
    assert_equal 2, Crawling::ScanEvent.count
  end

  test "same idempotency key with a different command fails without changing the first scan" do
    command = command_for("admission-conflict")
    original = admit(command)
    conflicting = Crawling::AdmissionRequest.new(
      idempotency_key: command.idempotency_key,
      source: "manual",
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      scan_type: "targeted"
    )

    error = assert_raises(Crawling::AdmissionIdempotencyConflict) { admit(conflicting) }

    assert_equal "idempotency_conflict", error.definition.public_code
    assert_equal "full", original.reload.scan_type
    assert_equal 1, Crawling::Scan.count
    assert_equal 1, Usage::QuotaReservation.count
  end

  test "enqueue failure leaves an admitted held scan recoverable by the bounded sweep" do
    CapturingJob.failure = RuntimeError.new("queue is unavailable")
    scan = admit(command_for("enqueue-recovery"))

    assert_equal "admitted", scan.reload.status
    assert_nil scan.dispatch_enqueued_at
    assert_equal "enqueue_failed", scan.dispatch_last_error_category
    assert scan.quota_reservation.held?

    CapturingJob.failure = nil
    enqueuer = Crawling::EnqueueScanDispatch.new(job_class: CapturingJob, clock: -> { @now + 1.second })
    Crawling::SchedulePendingDispatches.new(enqueuer: enqueuer).call

    assert scan.reload.dispatch_enqueued_at
    assert_equal scan.id, CapturingJob.arguments.fetch(:scan_id)
    assert scan.quota_reservation.reload.held?
  end

  test "expired verification and unsafe preflight create neither a scan nor a quota hold" do
    expired = Crawling::AdmitScan.new(
      clock: -> { @now + 31.days },
      preflight: @preflight,
      dispatch_enqueuer: successful_enqueuer
    )
    assert_raises(Crawling::VerificationRequired) do
      expired.call(actor_membership: @owner.membership, request: command_for("expired-proof"))
    end

    unsafe = ->(environment:) { raise Crawling::TargetUnsafe }
    service = admission_service(preflight: unsafe)
    assert_raises(Crawling::TargetUnsafe) do
      service.call(actor_membership: @owner.membership, request: command_for("unsafe-target"))
    end

    assert_equal 0, Crawling::Scan.count
    assert_equal 0, Usage::QuotaReservation.count
    assert_equal 0, Usage::UsageWindow.count
  end

  test "organization concurrency rejects a second scan before quota reservation" do
    first = admit(command_for("capacity-first"))
    assert first.quota_reservation.held?

    error = assert_raises(Crawling::CapacityExceeded) do
      admit(command_for("capacity-second"))
    end

    assert_equal "organization", error.scope
    assert_equal 1, Crawling::Scan.count
    assert_equal 1, Usage::QuotaReservation.count
  end

  test "project and global capacity scopes are enforced against active scans" do
    admit(command_for("capacity-scope"))
    capacity = Crawling::ScanCapacity.new

    project_error = assert_raises(Crawling::CapacityExceeded) do
      capacity.check!(
        organization_id: @owner.organization.id,
        project_id: @project.id,
        limits: Crawling::ConcurrentScanLimits.new(
          organization: 2, project: 1, global: 10, provenance: "test"
        )
      )
    end
    assert_equal "project", project_error.scope

    global_error = assert_raises(Crawling::CapacityExceeded) do
      capacity.check!(
        organization_id: @owner.organization.id,
        project_id: @project.id,
        limits: Crawling::ConcurrentScanLimits.new(
          organization: 2, project: 2, global: 1, provenance: "test"
        )
      )
    end
    assert_equal "global", global_error.scope
  end

  test "quota denial rolls back usage window and scan persistence" do
    definition = Entitlements::Definition.find_by!(key: "crawl.credits_monthly")
    Entitlements::OrganizationOverride.create!(
      organization_id: @owner.organization.id,
      entitlement_definition_id: definition.id,
      value_type: "integer",
      value: 20,
      starts_at: @now - 1.minute,
      reason: "Admission quota test",
      source: "support",
      created_by_membership_id: @owner.membership.id
    )
    Current.entitlement_cache = nil

    assert_raises(Usage::QuotaExceeded) { admit(command_for("quota-denied")) }

    assert_equal 0, Crawling::Scan.count
    assert_equal 0, Usage::QuotaReservation.count
    assert_equal 0, Usage::UsageWindow.count
  end

  test "dispatch job revalidates the held reservation before queueing" do
    scan = admit(command_for("dispatch-worker"))

    Crawling::ScanDispatchJob.perform_now(organization_id: scan.organization_id, scan_id: scan.id)

    assert_equal "queued", scan.reload.status
    assert_equal "crawl", Crawling::ScanDispatchJob.new.queue_name
    assert_equal "scan.queued", scan.events.order(:sequence).last.event_type
  end

  test "dispatch fails closed when its durable quota hold has expired" do
    scan = admit(command_for("dispatch-expired-hold"))

    Crawling::DispatchScan.new(clock: -> { @now + 3.hours }).call(
      organization_id: scan.organization_id,
      scan_id: scan.id
    )

    assert_equal "failed", scan.reload.status
    assert_equal "quota_reservation_unavailable", scan.failure_category
    assert_equal "scan.failed", scan.events.order(:sequence).last.event_type
  end

  test "cross tenant request is denied before preflight and all mutations" do
    foreign = create_organization_for(slug: "scan-admission-foreign")
    calls = 0
    preflight = ->(environment:) { calls += 1 }
    service = admission_service(preflight: preflight)

    assert_raises(Crawling::AccessDenied) do
      service.call(actor_membership: foreign.membership, request: command_for("foreign-denied"))
    end

    assert_equal 0, calls
    assert_equal 0, Crawling::Scan.count
    assert_equal 0, Usage::QuotaReservation.count
  end

  private

  def command_for(key)
    Crawling::AdmissionRequest.new(
      idempotency_key: key,
      source: "manual",
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      scan_type: "full"
    )
  end

  def admit(command)
    admission_service.call(actor_membership: @owner.membership, request: command)
  end

  def admission_service(preflight: @preflight)
    Crawling::AdmitScan.new(
      clock: -> { @now },
      preflight: preflight,
      dispatch_enqueuer: successful_enqueuer
    )
  end

  def successful_enqueuer
    Crawling::EnqueueScanDispatch.new(job_class: CapturingJob, clock: -> { @now })
  end

  def create_fresh_verification(owner, project, property, environment, at)
    Verification::Challenge.create!(
      organization_id: owner.organization.id,
      project_id: project.id,
      property_id: property.id,
      environment_id: environment.id,
      issued_by_membership_id: owner.membership.id,
      method: "dns_txt",
      challenge_digest: Digest::SHA256.hexdigest("scan-admission-proof"),
      expected_location: "_searchops.#{environment.host}",
      bound_origin: environment.origin,
      state: "verified",
      attempt_count: 0,
      verified_at: at - 1.hour,
      expires_at: at + 90.days,
      evidence: {},
      created_at: at - 1.hour,
      updated_at: at - 1.hour
    )
  end
end
