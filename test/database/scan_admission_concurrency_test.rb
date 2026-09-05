# frozen_string_literal: true

require "test_helper"

class ScanAdmissionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Current.reset
    sync_usage_catalog
    @now = Time.current.change(usec: 0)
    @owner, = create_subscribed_usage_organization(plan_key: "starter", slug: "admission-concurrency")
    enable_project_limit(@owner, at: @now)
    enable_property_limits(@owner, at: @now)
    enable_crawl_policy(
      @owner,
      values: { "crawl.concurrent_scans" => [ "integer", 1 ] },
      at: @now
    )
    @project = create_project_for(@owner, slug: "admission-concurrency-project", at: @now)
    @property = create_property_for(@owner, project: @project, at: @now)
    @environment = @property.environments.sole
    create_fresh_verification
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "concurrent duplicate requests return one scan and one quota reservation" do
    request = command("same-request")
    results = concurrently([ request, request ])

    assert_equal 1, results.uniq.length, results.inspect
    assert_empty results.grep(/error:/)
    assert_equal 1, Crawling::Scan.count
    assert_equal 1, Usage::QuotaReservation.count
    assert_equal 2, Crawling::ScanEvent.count
  end

  test "transactional organization capacity admits only one distinct racer" do
    results = concurrently([ command("racer-one"), command("racer-two") ])

    assert_equal 1, results.count { |value| Shared::Public.application_uuid?(value) }, results.inspect
    assert_equal 1, results.count("scan_capacity_exceeded"), results.inspect
    assert_empty results.grep(/error:/)
    assert_equal 1, Crawling::Scan.count
    assert_equal 1, Usage::QuotaReservation.count
  end

  private

  def command(key)
    Crawling::AdmissionRequest.new(
      idempotency_key: key,
      source: "manual",
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      scan_type: "full"
    )
  end

  def service
    preflight = ->(environment:) {
      Crawling::PreflightResult.new(
        checked_at: @now,
        status_code: 200,
        destination_digest: Digest::SHA256.hexdigest(environment.origin.origin),
        redirect_count: 0
      )
    }
    Crawling::AdmitScan.new(
      clock: -> { @now },
      preflight: preflight,
      dispatch_enqueuer: ->(organization_id:, scan_id:) { true }
    )
  end

  def concurrently(requests)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = requests.map do |request|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Current.reset
          membership = Tenancy::Membership.find(@owner.membership.id)
          ready << true
          start.pop
          results << service.call(actor_membership: membership, request: request).id
        rescue Crawling::CapacityExceeded => error
          results << error.reason_code
        rescue StandardError => error
          results << "error:#{error.class.name}:#{error.message}"
        ensure
          Current.reset
        end
      end
    end
    requests.length.times { ready.pop }
    requests.length.times { start << true }
    threads.each(&:join)
    requests.length.times.map { results.pop }
  end

  def create_fresh_verification
    Verification::Challenge.create!(
      organization_id: @owner.organization.id,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      issued_by_membership_id: @owner.membership.id,
      method: "dns_txt",
      challenge_digest: Digest::SHA256.hexdigest("admission-concurrency-proof"),
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

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE usage_meter_definitions, entitlement_definitions, plans, " \
        "organizations, users, audit_events CASCADE"
    )
  end
end
