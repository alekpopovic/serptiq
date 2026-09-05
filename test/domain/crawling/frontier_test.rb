# frozen_string_literal: true

require "test_helper"

class CrawlingFrontierTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "crawl-frontier")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "frontier-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property, at: @now - 2.seconds)
    @scan = run_scan_to(@scan, "queued", at: @now - 1.second)
  end

  test "batch discovery deduplicates canonical identities and updates aggregate progress once" do
    first = entry("https://example.com/", priority: 100, source: "seed")
    child = entry("https://example.com/about", depth: 2, priority: 1, source: "link")

    result = discover(first, child)
    replay = discover(first, entry("https://example.com/about", depth: 1, priority: 50, source: "link"))

    assert_equal 2, result.inserted_count
    assert_equal 0, replay.inserted_count
    assert_equal 2, Crawling::CrawlUrl.where(scan_id: @scan.id).count
    assert_equal 2, @scan.reload.urls_discovered_count
    assert_equal 2, @scan.urls_queued_count
    assert_equal 0, @scan.urls_running_count
    assert_equal 1, @scan.events.where(event_type: "scan.progress_recorded").count
    promoted = Crawling::CrawlUrl.find_by!(normalized_url: "https://example.com/about")
    assert_equal 1, promoted.depth
    assert_equal 50, promoted.priority
  end

  test "frontier input has deterministic versioned identity and rejects malformed provenance" do
    upper = entry("HTTPS://EXAMPLE.COM/path")
    lower = entry("https://example.com/path")

    assert_equal lower.normalized_url, upper.normalized_url
    assert_equal lower.normalized_url_digest, upper.normalized_url_digest
    assert_match(/\A[0-9a-f]{64}\z/, upper.host_digest)
    assert_raises(ArgumentError) { entry("https://user:secret@example.com/path") }
    assert_raises(ArgumentError) do
      Crawling::FrontierEntry.new(
        url: "https://example.com/",
        depth: 101,
        discovery_source: "unknown"
      )
    end
  end

  test "frontier deduplicates identity variants while preserving the first fetch URL" do
    first = Crawling::Public.frontier_entry(
      url: "https://example.com/product?id=7&utm_source=first",
      depth: 0,
      discovery_source: "seed",
      query_handling: "tracking_only"
    )
    second = Crawling::Public.frontier_entry(
      url: "https://example.com/product?utm_source=second&id=7",
      depth: 1,
      discovery_source: "link",
      query_handling: "tracking_only"
    )

    result = discover(first, second)

    assert_equal 1, result.inserted_count
    item = result.items.sole
    assert_equal "https://example.com/product?id=7&utm_source=first", item.fetch_url
    assert_equal "https://example.com/product?id=7", item.normalized_url
    assert_equal 2, item.normalization_version
  end

  test "a digest collision rolls back discovery instead of merging different URLs" do
    digestor = ->(_value) { "a" * 64 }
    entries = %w[one two].map do |path|
      Crawling::FrontierEntry.new(
        url: "https://example.com/#{path}",
        depth: 0,
        discovery_source: "seed",
        digestor: digestor
      )
    end

    error = assert_raises(Crawling::Conflict) { discover(*entries) }

    assert_equal "frontier_digest_collision", error.reason_code
    assert_equal 0, Crawling::CrawlUrl.where(scan_id: @scan.id).count
    assert_equal 0, @scan.reload.urls_discovered_count
  end

  test "leasing uses bounded opaque ownership, supports heartbeat and idempotent success" do
    discover(
      entry("https://example.com/shallow", depth: 0, priority: 10),
      entry("https://other.example.com/deep", depth: 2, priority: 1)
    )
    leases = lease(worker: "crawl-worker-1", limit: 2)
    first = leases.find { |candidate| candidate.normalized_url == "https://example.com/shallow" }

    assert_equal 2, leases.length
    assert first
    assert_equal 64, first.token.bytesize
    refute_includes Crawling::CrawlUrl.find(first.id).attributes.values, first.token
    assert_equal 0, @scan.reload.urls_queued_count
    assert_equal 2, @scan.urls_running_count

    heartbeat_at = @now + 30.seconds
    heartbeat = Crawling::HeartbeatFrontierLease.new(clock: -> { heartbeat_at }).call(
      organization_id: first.organization_id,
      crawl_url_id: first.id,
      worker_id: first.worker_id,
      lease_token: first.token,
      lease_duration: 90
    )
    assert_equal heartbeat_at + 90.seconds, heartbeat.lease_expires_at

    service = Crawling::FinishFrontierItem.new(clock: -> { @now + 40.seconds })
    completed = finish(service, first)
    replay = finish(service, first)

    assert_equal "succeeded", completed.state
    assert_equal completed.id, replay.id
    assert_equal 1, @scan.reload.urls_processed_count
    assert_equal 1, @scan.urls_succeeded_count
    assert_equal 1, @scan.urls_running_count
  end

  test "retry returns work to the queue and permanent failure is terminal and idempotent" do
    discover(entry("https://example.com/flaky"))
    first = lease(worker: "worker-retry").sole
    retry_service = Crawling::FailFrontierItem.new(clock: -> { @now + 1.second })
    retry_attributes = {
      organization_id: first.organization_id,
      crawl_url_id: first.id,
      worker_id: first.worker_id,
      lease_token: first.token,
      failure_category: "http_timeout",
      retryable: true
    }
    retrying = retry_service.call(**retry_attributes)
    retry_replay = retry_service.call(**retry_attributes)

    assert_equal "pending", retrying.state
    assert_equal retrying.id, retry_replay.id
    assert_equal "retry", retrying.last_lease_outcome
    assert_equal 1, @scan.reload.urls_queued_count
    assert_equal 0, @scan.urls_running_count

    second = lease(worker: "worker-retry", at: retrying.next_attempt_at).sole
    service = Crawling::FailFrontierItem.new(clock: -> { retrying.next_attempt_at + 1.second })
    failed = permanently_fail(service, second)
    replay = permanently_fail(service, second)

    assert_equal "failed", failed.state
    assert_equal failed.id, replay.id
    assert_equal 1, @scan.reload.urls_processed_count
    assert_equal 1, @scan.urls_failed_count
    assert_equal 0, @scan.urls_queued_count
    assert_equal 0, @scan.urls_running_count
  end

  test "expired leases recover for retry and exhaust their persisted attempt budget" do
    discover(entry("https://example.com/crash"))
    first = lease(worker: "worker-crash", duration: 15).sole
    recovered = recover(after: first.expires_at)

    assert_equal [ first.id ], recovered.map(&:id)
    assert_equal "pending", recovered.sole.state
    assert_equal "stale_recovered", recovered.sole.last_lease_outcome

    2.times do |index|
      item = Crawling::CrawlUrl.find(first.id)
      lease_record = lease(
        worker: "worker-crash-#{index}",
        at: item.next_attempt_at,
        duration: 15
      ).sole
      recover(after: lease_record.expires_at)
    end

    assert_equal "exhausted", Crawling::CrawlUrl.find(first.id).state
    assert_equal 1, @scan.reload.urls_processed_count
    assert_equal 1, @scan.urls_failed_count
    assert_equal 0, @scan.urls_running_count
  end

  test "wrong tenant, owner or token cannot observe or mutate a lease" do
    discover(entry("https://example.com/private"))
    leased = lease(worker: "tenant-worker").sole
    foreign = create_organization_for(slug: "crawl-frontier-foreign")

    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.frontier_progress(
        organization_id: foreign.organization.id,
        scan_id: @scan.id
      )
    end
    %w[wrong-worker tenant-worker].each_with_index do |worker, index|
      token = index.zero? ? leased.token : "0" * 64
      assert_raises(Crawling::Conflict) do
        Crawling::Public.heartbeat_frontier_lease(
          organization_id: leased.organization_id,
          crawl_url_id: leased.id,
          worker_id: worker,
          lease_token: token
        )
      end
    end
    assert_equal "leased", Crawling::CrawlUrl.find(leased.id).state
  end

  test "global leasing gives organizations and hosts a fair first round" do
    dominant = 5.times.map do |index|
      entry("https://large.example.com/page-#{index}", priority: 100 - index)
    end
    discover(*dominant, entry("https://second.example.com/low", priority: 0))

    other = create_organization_for(slug: "crawl-frontier-fair")
    enable_project_limit(other)
    enable_property_limits(other)
    project = create_project_for(other, slug: "fair-project")
    property = create_property_for(other, project: project)
    scan = create_scan_for(other, project: project, property: property, at: @now - 2.seconds)
    scan = run_scan_to(scan, "queued", at: @now - 1.second)
    Crawling::Public.discover_frontier(
      organization_id: scan.organization_id,
      scan_id: scan.id,
      entries: [ entry("https://third.example.com/low", priority: 0) ],
      clock: -> { @now }
    )

    leases = lease(worker: "fair-worker", limit: 3)

    assert_equal 2, leases.map(&:organization_id).uniq.length
    assert_equal 3, leases.map(&:host_digest).uniq.length
    assert_includes leases.map(&:normalized_url), "https://second.example.com/low"
    assert_includes leases.map(&:normalized_url), "https://third.example.com/low"
  end

  test "progress projection reads scan counters without aggregating frontier rows" do
    discover(entry("https://example.com/one"), entry("https://example.com/two"))
    sql = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      sql << payload[:sql] if payload[:sql]&.match?(/SELECT/i)
    end
    snapshot = ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      Crawling::Public.frontier_progress(organization_id: @scan.organization_id, scan_id: @scan.id)
    end

    assert_equal 2, snapshot.urls_discovered_count
    assert_equal 2, snapshot.urls_queued_count
    assert sql.none? { |statement| statement.match?(/COUNT\s*\(.*crawl_urls/i) }, sql.inspect
  end

  private

  def entry(url, depth: 0, priority: 0, source: "seed")
    Crawling::Public.frontier_entry(
      url: url,
      depth: depth,
      priority: priority,
      discovery_source: source
    )
  end

  def discover(*entries)
    Crawling::Public.discover_frontier(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      entries: entries,
      clock: -> { @now }
    )
  end

  def lease(worker:, limit: 10, at: @now, duration: 120)
    Crawling::LeaseFrontier.new(clock: -> { at }).call(
      worker_id: worker,
      limit: limit,
      lease_duration: duration
    )
  end

  def recover(after:)
    Crawling::RecoverStaleFrontierLeases.new(clock: -> { after + 1.second }).call
  end

  def finish(service, lease_record)
    result = create_crawl_fetch_result_for(
      scan: @scan,
      crawl_url: Crawling::CrawlUrl.find(lease_record.id),
      lease_token: lease_record.token,
      at: @now + 39.seconds
    )
    service.call(
      organization_id: lease_record.organization_id,
      crawl_url_id: lease_record.id,
      worker_id: lease_record.worker_id,
      lease_token: lease_record.token,
      outcome: "succeeded",
      fetch_result_id: result.id,
      http_status_code: 200
    )
  end

  def permanently_fail(service, lease_record)
    result = create_crawl_fetch_result_for(
      scan: @scan,
      crawl_url: Crawling::CrawlUrl.find(lease_record.id),
      lease_token: lease_record.token,
      at: @now,
      outcome: "http_error",
      status: 502
    )
    service.call(
      organization_id: lease_record.organization_id,
      crawl_url_id: lease_record.id,
      worker_id: lease_record.worker_id,
      lease_token: lease_record.token,
      failure_category: "invalid_response",
      retryable: false,
      fetch_result_id: result.id,
      http_status_code: 502
    )
  end
end
