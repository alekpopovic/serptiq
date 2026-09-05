# frozen_string_literal: true

require "test_helper"

class CrawlFrontierConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Current.reset
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "frontier-concurrency")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "frontier-concurrency-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property, at: @now - 2.seconds)
    @scan = run_scan_to(@scan, "queued", at: @now - 1.second)
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "concurrent duplicate discovery inserts and counts one normalized URL" do
    frontier_entry = entry("https://example.com/concurrent")
    results = concurrently(2) do
      Crawling::DiscoverFrontier.new(clock: -> { @now }).call(
        organization_id: @scan.organization_id,
        scan_id: @scan.id,
        entries: [ frontier_entry ]
      ).inserted_count
    end

    assert_equal [ 0, 1 ], results.sort
    assert_equal 1, Crawling::CrawlUrl.where(scan_id: @scan.id).count
    assert_equal 1, @scan.reload.urls_discovered_count
    assert_equal 1, @scan.urls_queued_count
  end

  test "SKIP LOCKED workers never receive the same frontier item" do
    entries = 20.times.map { |index| entry("https://example.com/page-#{index}") }
    Crawling::DiscoverFrontier.new(clock: -> { @now }).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      entries: entries
    )

    batches = concurrently(2) do |index|
      Crawling::LeaseFrontier.new(clock: -> { @now }).call(
        worker_id: "concurrent-worker-#{index}",
        limit: 10,
        lease_duration: 120
      ).map(&:id)
    end
    all_ids = batches.flatten

    assert_equal 20, all_ids.length
    assert_equal 20, all_ids.uniq.length
    assert_equal 20, Crawling::CrawlUrl.where(state: "leased").count
    assert_equal 0, @scan.reload.urls_queued_count
    assert_equal 20, @scan.urls_running_count
  end

  test "concurrent stale recovery processes one expired lease once" do
    Crawling::DiscoverFrontier.new(clock: -> { @now }).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      entries: [ entry("https://example.com/crashed") ]
    )
    lease_record = Crawling::LeaseFrontier.new(clock: -> { @now }).call(
      worker_id: "crashed-worker",
      limit: 1,
      lease_duration: 15
    ).sole
    recovery_at = lease_record.expires_at + 1.second

    recovered = concurrently(2) do
      Crawling::RecoverStaleFrontierLeases.new(clock: -> { recovery_at }).call.map(&:id)
    end

    assert_equal [ [], [ lease_record.id ] ], recovered.sort_by(&:length)
    assert_equal "pending", Crawling::CrawlUrl.find(lease_record.id).state
    assert_equal 1, @scan.reload.urls_queued_count
    assert_equal 0, @scan.urls_running_count
  end

  private

  def entry(url)
    Crawling::FrontierEntry.new(url: url, depth: 0, discovery_source: "seed")
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
          results << "error:#{error.class.name}:#{error.message}"
        ensure
          Current.reset
        end
      end
    end
    count.times { ready.pop }
    count.times { start << true }
    threads.each(&:join)
    count.times.map { results.pop }
  end

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE entitlement_definitions, plans, organizations, users, audit_events CASCADE"
    )
  end
end
