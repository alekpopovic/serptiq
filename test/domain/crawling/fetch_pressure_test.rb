# frozen_string_literal: true

require "test_helper"

class CrawlingFetchPressureTest < ActiveSupport::TestCase
  FixedLimits = Struct.new(:value) do
    def call(scan:, at:)
      value.call(scan, at)
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "fetch-pressure")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "fetch-pressure-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(
      @owner,
      project: @project,
      property: @property,
      at: @now - 2.minutes,
      settings_snapshot: {
        "max_urls" => 20,
        "robots_behavior" => "respect",
        "max_concurrency" => 4,
        "request_rate_per_second" => "4.0"
      },
      entitlement_snapshot: {
        "crawl.manual" => true,
        "crawl.concurrent_scans" => { "organization" => 2 }
      }
    )
    @scan = run_scan_to(@scan, "running", at: @now - 1.minute)
  end

  test "host key includes normalized scheme hostname and explicit effective port" do
    default_https = Crawling::Public.host_key(url: "HTTPS://BÜCHER.example./path")
    explicit_https = Crawling::Public.host_key(url: "https://xn--bcher-kva.example:443/other")
    http = Crawling::Public.host_key(url: "http://xn--bcher-kva.example/")
    alternate_port = Crawling::Public.host_key(url: "https://xn--bcher-kva.example:8443/")

    assert_equal "https", default_https.scheme
    assert_equal "xn--bcher-kva.example", default_https.hostname
    assert_equal 443, default_https.port
    assert_equal default_https.digest, explicit_https.digest
    refute_equal default_https.digest, http.digest
    refute_equal default_https.digest, alternate_port.digest
    refute_includes default_https.inspect, "xn--bcher"
  end

  test "effective limits compose global plan-derived organization scan and host caps" do
    limits = Crawling::ResolvePressureLimits.new.call(scan: @scan, at: @now)

    assert_equal 4, limits.global_concurrency
    assert_equal 4, limits.organization_concurrency
    assert_equal 1, limits.scan_concurrency
    assert_equal 1, limits.host_concurrency
    assert_equal 4.0, limits.scan_rate
    assert_equal 2.0, limits.host_rate
    assert_equal 1, limits.effective_concurrency
    assert_equal 2.0, limits.effective_rate
    assert_equal @scan.started_at + 30.minutes, limits.scan_deadline
  end

  test "configured rate and Retry-After produce bounded durable host throttling" do
    first, second = lease_urls("https://example.com/one", "https://example.com/two")
    limits = fixed_limits(host_rate: 2.0)
    acquired = acquire(first, limits: limits)
    release(acquired, outcome: "succeeded", status: 200)

    throttled = acquire(second, limits: limits)
    assert throttled.throttled?
    assert_equal "host_rate", throttled.reason_code
    assert_equal @now + 0.5.seconds, throttled.retry_at
    assert_equal "host_rate", @scan.reload.throttle_reason

    retry_at = throttled.retry_at
    acquired = acquire(second, limits: limits, at: retry_at)
    release(
      acquired,
      outcome: "http_error",
      status: 429,
      failure_category: "http_429",
      retry_after: "120",
      at: retry_at
    )
    third = lease_urls("https://example.com/three", at: retry_at).sole
    backed_off = acquire(third, limits: limits, at: retry_at)

    assert backed_off.throttled?
    assert_equal "host_backoff", backed_off.reason_code
    assert_equal retry_at + 60.seconds, backed_off.retry_at
    host = Crawling::PressureState.find_by!(scope_type: "host")
    assert_equal 1, host.failure_streak
    assert_equal retry_at + 60.seconds, host.backoff_until
  end

  test "scan cancellation and maximum duration prevent new or infinite delayed work" do
    lease = lease_urls("https://cancel.example.com/").sole
    @scan = Crawling::RequestScanCancellation.new(clock: -> { @now }).call(
      actor_membership: @owner.membership,
      project_id: @project.id,
      scan_id: @scan.id
    )
    canceled = acquire(lease, limits: fixed_limits)

    assert_equal "canceled", canceled.state
    assert_equal "scan_canceled", canceled.reason_code
    assert_nil canceled.permit

    other_scan, other_lease = running_scan_and_lease("deadline", "https://deadline.example.com/")
    expired_limits = fixed_limits(deadline: @now - 1.second)
    exhausted = acquire(other_lease, limits: expired_limits)

    assert_equal "exhausted", exhausted.state
    assert_equal "scan_deadline_exceeded", exhausted.reason_code
    assert_equal 0, Crawling::FetchPermit.where(scan_id: other_scan.id).count
  end

  test "transient network failures apply capped exponential host backoff" do
    first, second = lease_urls(
      "https://network-failure.example.com/one",
      "https://network-failure.example.com/two"
    )
    acquired = acquire(first, limits: fixed_limits)
    release(
      acquired,
      outcome: "failed",
      failure_category: "connect_timeout"
    )

    decision = acquire(second, limits: fixed_limits)

    assert decision.throttled?
    assert_equal "host_backoff", decision.reason_code
    assert_equal @now + 1.second, decision.retry_at
  end

  test "stale permits expire and a later owner can acquire without a leaked slot" do
    first, second = lease_urls("https://stale.example.com/one", "https://other.example.com/two")
    acquired = acquire(first, limits: fixed_limits(duration: 15))
    permit = Crawling::FetchPermit.find(acquired.permit.id)

    recovered = Crawling::RecoverStaleFetchPermits.new(
      clock: -> { permit.expires_at + 1.second }
    ).call

    assert_equal [ permit.id ], recovered.map(&:id)
    assert_equal "expired", permit.reload.state
    later = acquire(second, limits: fixed_limits(duration: 15), at: permit.expires_at + 1.second)
    assert later.acquired?
  end

  test "an active frontier permit produces a bounded replay throttle" do
    lease = lease_urls("https://active-permit.example.com/").sole
    first = acquire(lease, limits: fixed_limits(duration: 15))
    replay = acquire(lease, limits: fixed_limits(duration: 15))

    assert first.acquired?
    assert replay.throttled?
    assert_equal "frontier_permit_active", replay.reason_code
    assert_equal first.permit.expires_at, replay.retry_at
    assert_equal 1, Crawling::FetchPermit.where(crawl_url_id: lease.id, state: "active").count
  end

  test "platform-only global and host kill switches are audited without target disclosure" do
    lease = lease_urls("https://blocked.example.com/private?token=secret").sole
    assert_raises(Crawling::OperatorAccessDenied) do
      Crawling::Public.set_emergency_control(
        user: @owner.membership,
        scope: "global",
        disabled: true,
        reason_code: "incident_response",
        clock: -> { @now }
      )
    end

    Crawling::ControlAccessGrant.create!(
      user_id: @owner.membership.user_id,
      permission: Crawling::ControlAccessGrant::PERMISSION,
      granted_at: @now - 1.minute
    )
    state = Crawling::Public.set_emergency_control(
      user: @owner.membership.user,
      scope: "global",
      disabled: true,
      reason_code: "incident_response",
      clock: -> { @now }
    )
    decision = acquire(lease, limits: fixed_limits)

    assert state.disabled?
    assert_equal "global_disabled", decision.reason_code
    audit = Auditing::AuditEvent.where(action: "crawler.emergency_control_changed").sole
    assert_equal @owner.membership.user_id, audit.actor_user_id
    assert_nil audit.organization_id
    assert_equal "global", audit.metadata.fetch("scope_type")
    refute_includes audit.attributes.inspect, "blocked.example.com"
    refute_includes audit.attributes.inspect, "token=secret"

    resumed = Crawling::Public.set_emergency_control(
      user: @owner.membership.user,
      scope: "global",
      disabled: false,
      reason_code: "incident_resolved",
      clock: -> { @now + 1.second }
    )
    refute resumed.disabled?

    host_state = Crawling::Public.set_emergency_control(
      user: @owner.membership.user,
      scope: "host",
      url: lease.fetch_url,
      disabled: true,
      reason_code: "host_incident",
      clock: -> { @now + 2.seconds }
    )
    host_decision = acquire(lease, limits: fixed_limits, at: @now + 2.seconds)
    assert host_state.disabled?
    assert_equal "host_disabled", host_decision.reason_code
    refute_includes Auditing::AuditEvent.where(target_id: host_state.id).sole.attributes.inspect,
      "blocked.example.com"
  end

  test "operator metrics expose bounded pressure counts" do
    lease = lease_urls("https://metrics.example.com/").sole
    acquired = acquire(lease, limits: fixed_limits(duration: 15))
    Crawling::Scan.where(id: @scan.id).update_all(
      throttled_at: @now,
      throttle_reason: "host_rate",
      throttle_until: @now + 1.second
    )

    snapshot = Crawling::PressureMetrics.new(clock: -> { @now }).call

    assert_equal 1, snapshot.active_permits
    assert_equal 0, snapshot.stale_permits
    assert_equal 1, snapshot.throttled_scans
    assert_operator snapshot.maximum_wait_seconds, :>=, 1
    refute snapshot.alerting
    assert_equal "active", Crawling::FetchPermit.find(acquired.permit.id).state
  end

  private

  def lease_urls(*urls, at: @now)
    entries = urls.map do |url|
      Crawling::FrontierEntry.new(url: url, depth: 0, discovery_source: "seed")
    end
    Crawling::Public.discover_frontier(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      entries: entries,
      clock: -> { at }
    )
    Crawling::LeaseFrontier.new(clock: -> { at }).call(
      worker_id: "pressure-worker",
      limit: urls.length,
      lease_duration: 120
    )
  end

  def running_scan_and_lease(slug, url)
    owner = create_organization_for(slug: "fetch-pressure-#{slug}")
    enable_project_limit(owner)
    enable_property_limits(owner)
    project = create_project_for(owner, slug: "#{slug}-project")
    property = create_property_for(owner, project: project)
    scan = create_scan_for(owner, project: project, property: property, at: @now - 2.minutes)
    scan = run_scan_to(scan, "running", at: @now - 1.minute)
    entry = Crawling::FrontierEntry.new(url: url, depth: 0, discovery_source: "seed")
    Crawling::Public.discover_frontier(
      organization_id: scan.organization_id,
      scan_id: scan.id,
      entries: [ entry ],
      clock: -> { @now }
    )
    lease = Crawling::LeaseFrontier.new(clock: -> { @now }).call(
      worker_id: "deadline-worker", limit: 1, lease_duration: 120
    ).find { |candidate| candidate.scan_id == scan.id }
    [ scan, lease ]
  end

  def context(lease)
    Crawling::FetchPermitContext.new(
      organization_id: lease.organization_id,
      scan_id: lease.scan_id,
      crawl_url_id: lease.id,
      worker_id: lease.worker_id,
      frontier_lease_token: lease.token
    )
  end

  def acquire(lease, limits:, at: @now)
    Crawling::AcquireFetchPermit.new(
      clock: -> { at },
      limits: FixedLimits.new(->(_scan, _time) { limits }),
      emitter: ->(*) { }
    ).call(context: context(lease), url: lease.fetch_url)
  end

  def release(decision, outcome:, status: nil, failure_category: nil, retry_after: nil, at: @now)
    Crawling::ReleaseFetchPermit.new(clock: -> { at }, emitter: ->(*) { }).call(
      organization_id: @scan.organization_id,
      permit_id: decision.permit.id,
      permit_token: decision.permit.token,
      outcome: outcome,
      http_status_code: status,
      failure_category: failure_category,
      retry_after: retry_after
    )
  end

  def fixed_limits(host_rate: 1000.0, duration: 60, deadline: @now + 20.minutes)
    Crawling::PressureLimits.new(
      global_concurrency: 100,
      organization_concurrency: 50,
      scan_concurrency: 20,
      host_concurrency: 10,
      global_rate: 1000,
      organization_rate: 1000,
      scan_rate: 1000,
      host_rate: host_rate,
      permit_duration: duration,
      scan_deadline: deadline
    )
  end
end
