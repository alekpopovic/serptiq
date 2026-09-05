# frozen_string_literal: true

require "test_helper"

class ScanUsageConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  class NullDispatch
    def call(**)
      true
    end
  end

  setup do
    truncate_records
    Current.reset
    sync_usage_catalog
    @now = Time.current.change(usec: 0) - 1.hour
    @owner, = create_subscribed_usage_organization(plan_key: "starter", slug: "scan-usage-race")
    enable_project_limit(@owner, at: @now)
    enable_property_limits(@owner, at: @now)
    enable_crawl_policy(
      @owner,
      values: { "crawl.concurrent_scans" => [ "integer", 2 ] },
      at: @now
    )
    set_credit_limit(51)
    @project = create_project_for(@owner, slug: "scan-usage-race-project", at: @now)
    @property = create_property_for(@owner, project: @project, at: @now)
    @environment = @property.environments.sole
    create_fresh_verification
    @scans = 2.times.map { |index| admit("scan-usage-racer-#{index}") }
    @scans.each { |scan| run_scan_to(scan, "running", at: @now + 1.second) }
    @scans.each_with_index { |scan, index| consume_estimate(scan, index) }
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "PostgreSQL pool locking lets only one scan expand at the quota boundary" do
    outcomes = concurrently(@scans.each_with_index.map do |scan, index|
      -> {
        Crawling::Public.start_usage_operation(
          organization_id: scan.organization_id,
          scan_id: scan.id,
          source_key: "race:http:#{index}",
          operation_kind: "http_fetch",
          at: @now + 10.minutes
        )
        "reserved"
      }
    end)

    assert_equal 1, outcomes.count("reserved"), outcomes.inspect
    assert_equal 1, outcomes.count("usage_quota_exceeded"), outcomes.inspect
    assert_empty outcomes.grep(/unexpected/)
    assert_equal BigDecimal("50"), Usage::UsageEvent.where(event_kind: "usage").sum(:billed_quantity)
    assert_equal BigDecimal("51"), Usage::QuotaReservation.where(state: "held")
      .sum("held_quantity - consumed_quantity") + BigDecimal("50")
    assert_equal 1, Crawling::Scan.where(throttle_reason: "quota_exhausted").count
  end

  private

  def consume_estimate(scan, scan_index)
    operations = 5.times.map { |index| [ "http-#{index}", "http_fetch" ] } +
      2.times.map { |index| [ "render-#{index}", "rendered_page" ] }
    operations.each do |suffix, kind|
      source_key = "seed:#{scan_index}:#{suffix}"
      Crawling::Public.start_usage_operation(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        source_key: source_key,
        operation_kind: kind,
        at: @now + 5.minutes
      )
      Crawling::Public.finish_usage_operation(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        source_key: source_key,
        outcome: "accepted",
        occurred_at: @now + 5.minutes,
        at: @now + 5.minutes
      )
    end
    assert_equal BigDecimal("25"), scan.quota_reservation.reload.consumed_quantity
  end

  def concurrently(operations)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Current.reset
          ready << true
          start.pop
          results << operation.call
        rescue Usage::QuotaExceeded => error
          results << error.reason_code
        rescue StandardError => error
          results << "unexpected:#{error.class.name}:#{error.message}"
        ensure
          Current.reset
        end
      end
    end
    operations.length.times { ready.pop }
    operations.length.times { start << true }
    threads.each(&:join)
    operations.length.times.map { results.pop }
  end

  def admit(key)
    request = Crawling::AdmissionRequest.new(
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
    ).call(actor_membership: @owner.membership, request: request)
  end

  def create_fresh_verification
    Verification::Challenge.create!(
      organization_id: @owner.organization.id,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      issued_by_membership_id: @owner.membership.id,
      method: "dns_txt",
      challenge_digest: Digest::SHA256.hexdigest("scan-usage-race-proof"),
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
      reason: "Concurrent scan usage boundary",
      source: "support",
      created_by_membership_id: @owner.membership.id
    )
    Current.entitlement_cache = nil
  end

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE usage_meter_definitions, entitlement_definitions, plans, " \
        "organizations, users, audit_events CASCADE"
    )
  end
end
