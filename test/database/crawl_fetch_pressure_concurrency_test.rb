# frozen_string_literal: true

require "test_helper"

class CrawlFetchPressureConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  FixedLimits = Struct.new(:limits) do
    def call(scan:, at:)
      limits
    end
  end

  class SequencedClock
    def initialize(at)
      @at = at
      @mutex = Mutex.new
    end

    def call
      @mutex.synchronize do
        value = @at
        @at += 1.second
        value
      end
    end
  end

  setup do
    truncate_records
    Current.reset
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "concurrent workers never exceed global or normalized host limits" do
    owner, scan = running_scan("pressure-concurrency")
    leases = lease_urls(
      scan,
      "https://one.example.com/a",
      "https://one.example.com/b",
      "https://two.example.com/a",
      "https://two.example.com/b"
    )
    limits = pressure_limits(global: 2, host: 1)
    clock = SequencedClock.new(@now)

    decisions = concurrently(leases.length) do |index|
      acquire(leases.fetch(index), limits: limits, clock: clock)
    end
    acquired = decisions.filter(&:acquired?)

    assert_equal 2, acquired.length, decisions.map(&:reason_code).inspect
    active = Crawling::FetchPermit.active_at(clock.call)
    assert_equal 2, active.count
    assert_equal [ 1, 1 ], active.group(:host_key_digest).count.values.sort
    assert_equal 2, active.where(organization_id: owner.organization.id).count
    assert decisions.reject(&:acquired?).all?(&:throttled?)
  end

  test "fair frontier rounds preserve access for a second organization and host before pressure admission" do
    first_owner, first_scan = running_scan("pressure-fair-one")
    _second_owner, second_scan = running_scan("pressure-fair-two")
    lease_urls(first_scan, *5.times.map { |index| "https://dominant.example.com/#{index}" }, limit: 0)
    lease_urls(first_scan, "https://alternate.example.com/low", limit: 0)
    lease_urls(second_scan, "https://second.example.net/low", limit: 0)

    leases = Crawling::LeaseFrontier.new(clock: -> { @now }).call(
      worker_id: "fair-pressure-worker", limit: 3, lease_duration: 120
    )
    assert_equal 2, leases.map(&:organization_id).uniq.length
    assert_equal 3, leases.map(&:host_digest).uniq.length

    clock = SequencedClock.new(@now)
    decisions = concurrently(leases.length) do |index|
      acquire(leases.fetch(index), limits: pressure_limits(global: 3, host: 1), clock: clock)
    end

    assert_equal 3, decisions.count(&:acquired?)
    assert_equal 2, Crawling::FetchPermit.active_at(clock.call).pluck(:organization_id).uniq.length
    assert_includes Crawling::FetchPermit.pluck(:organization_id), first_owner.organization.id
  end

  test "organization and scan caps remain atomic across independent hosts" do
    first_owner, first_scan = running_scan("pressure-scope-one")
    _second_owner, second_scan = running_scan("pressure-scope-two")
    first_leases = lease_urls(
      first_scan,
      "https://scope-a.example.com/",
      "https://scope-b.example.com/",
      "https://scope-c.example.com/"
    )
    second_lease = lease_urls(second_scan, "https://scope-d.example.net/").sole
    leases = [ *first_leases, second_lease ]
    clock = SequencedClock.new(@now)
    limits = pressure_limits(global: 10, host: 10, organization: 1, scan: 1)

    decisions = concurrently(leases.length) do |index|
      acquire(leases.fetch(index), limits: limits, clock: clock)
    end
    active = Crawling::FetchPermit.active_at(clock.call)

    assert_equal 2, decisions.count(&:acquired?)
    assert_equal [ 1, 1 ], active.group(:organization_id).count.values.sort
    assert_equal [ 1, 1 ], active.group(:scan_id).count.values.sort
    assert_equal 1, active.where(organization_id: first_owner.organization.id).count
  end

  test "concurrent stale recovery expires each permit once" do
    _owner, scan = running_scan("pressure-stale")
    lease = lease_urls(scan, "https://stale-concurrent.example.com/").sole
    clock = SequencedClock.new(@now)
    decision = acquire(
      lease,
      limits: pressure_limits(global: 10, host: 10),
      clock: clock
    )
    recovery_at = decision.permit.expires_at + 1.second

    recovered = concurrently(2) do
      Crawling::RecoverStaleFetchPermits.new(clock: -> { recovery_at }).call.map(&:id)
    end

    assert_equal [ [], [ decision.permit.id ] ], recovered.sort_by(&:length)
    assert_equal "expired", Crawling::FetchPermit.find(decision.permit.id).state
  end

  private

  def running_scan(slug)
    owner = create_organization_for(slug: slug)
    enable_project_limit(owner)
    enable_property_limits(owner)
    project = create_project_for(owner, slug: "#{slug}-project")
    property = create_property_for(owner, project: project)
    scan = create_scan_for(owner, project: project, property: property, at: @now - 2.minutes)
    [ owner, run_scan_to(scan, "running", at: @now - 1.minute) ]
  end

  def lease_urls(scan, *urls, limit: urls.length)
    entries = urls.map do |url|
      Crawling::FrontierEntry.new(url: url, depth: 0, discovery_source: "seed")
    end
    Crawling::DiscoverFrontier.new(clock: -> { @now }).call(
      organization_id: scan.organization_id,
      scan_id: scan.id,
      entries: entries
    )
    return [] if limit.zero?

    Crawling::LeaseFrontier.new(clock: -> { @now }).call(
      worker_id: "pressure-concurrency-worker",
      limit: limit,
      lease_duration: 120
    ).select { |lease| lease.scan_id == scan.id }
  end

  def acquire(lease, limits:, clock:)
    context = Crawling::FetchPermitContext.new(
      organization_id: lease.organization_id,
      scan_id: lease.scan_id,
      crawl_url_id: lease.id,
      worker_id: lease.worker_id,
      frontier_lease_token: lease.token
    )
    Crawling::AcquireFetchPermit.new(
      clock: clock,
      limits: FixedLimits.new(limits),
      emitter: ->(*) { }
    ).call(context: context, url: lease.fetch_url)
  end

  def pressure_limits(global:, host:, organization: 10, scan: 10)
    Crawling::PressureLimits.new(
      global_concurrency: global,
      organization_concurrency: organization,
      scan_concurrency: scan,
      host_concurrency: host,
      global_rate: 100_000,
      organization_rate: 100_000,
      scan_rate: 100_000,
      host_rate: 100_000,
      permit_duration: 120,
      scan_deadline: @now + 1.hour
    )
  end

  def concurrently(count)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = count.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Current.reset
          ready << true
          start.pop
          results << yield(index)
        rescue StandardError => error
          results << error
        ensure
          Current.reset
        end
      end
    end
    count.times { ready.pop }
    count.times { start << true }
    threads.each(&:join)
    count.times.map { results.pop }.tap do |values|
      failure = values.find { |value| value.is_a?(Exception) }
      raise failure if failure
    end
  end

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE crawl_fetch_permits, crawl_pressure_states, crawl_control_access_grants, " \
        "entitlement_definitions, plans, organizations, users, audit_events CASCADE"
    )
  end
end
