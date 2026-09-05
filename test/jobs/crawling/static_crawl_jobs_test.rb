# frozen_string_literal: true

require "test_helper"

class CrawlingStaticCrawlJobsTest < ActiveJob::TestCase
  test "orchestrator delegates an exact tenant scan on the crawl queue" do
    arguments = nil
    with_public_method(:orchestrate_static_crawl, ->(**attributes) { arguments = attributes }) do
      Crawling::StaticCrawlOrchestratorJob.perform_now(
        organization_id: SecureRandom.uuid,
        scan_id: SecureRandom.uuid
      )
    end

    assert_equal "crawl", Crawling::StaticCrawlOrchestratorJob.new.queue_name
    assert_equal %i[organization_id scan_id worker_id], arguments.keys.sort
    assert_match(/\Acrawl-/, arguments.fetch(:worker_id))
  end

  test "analysis and recovery jobs delegate only their bounded operations" do
    extraction = nil
    conclusion = nil
    scan = Struct.new(:status) do
      def terminal? = false
    end.new("requested")

    with_public_method(:extract_static_page_links, ->(**attributes) { extraction = attributes }) do
      with_public_method(:conclude_static_crawl, ->(**attributes) { conclusion = attributes; scan }) do
        Crawling::StaticPageExtractionJob.perform_now(
          organization_id: SecureRandom.uuid,
          scan_id: SecureRandom.uuid,
          page_snapshot_id: 42
        )
      end
    end

    recovery_calls = 0
    with_public_method(:recover_static_crawl_work, -> { recovery_calls += 1 }) do
      Crawling::StaticCrawlSweepJob.perform_now
    end

    assert_equal "analysis", Crawling::StaticPageExtractionJob.new.queue_name
    assert_equal "maintenance", Crawling::StaticCrawlSweepJob.new.queue_name
    assert_equal extraction.slice(:organization_id, :scan_id), conclusion
    assert_equal 42, extraction.fetch(:page_snapshot_id)
    assert_match(/\Aextract-/, extraction.fetch(:worker_id))
    assert_equal 1, recovery_calls
  end

  test "dispatch starts static orchestration only for an eligible scan" do
    organization_id = SecureRandom.uuid
    scan_id = SecureRandom.uuid
    scan = Struct.new(:organization_id, :id, :status).new(organization_id, scan_id, "queued")

    with_public_method(:dispatch_scan, ->(**) { scan }) do
      assert_difference(
        -> { SolidQueue::Job.where(class_name: "Crawling::StaticCrawlOrchestratorJob").count }, 1
      ) do
        Crawling::ScanDispatchJob.perform_now(organization_id: organization_id, scan_id: scan_id)
      end
    end

    job = SolidQueue::Job.where(class_name: "Crawling::StaticCrawlOrchestratorJob")
      .order(:created_at, :id).last
    arguments = job.arguments.fetch("arguments").sole
    assert_equal organization_id, arguments.fetch("organization_id")
    assert_equal scan_id, arguments.fetch("scan_id")
  end

  private

  def with_public_method(name, replacement)
    original = Crawling::Public.method(name)
    Crawling::Public.define_singleton_method(name, &replacement)
    yield
  ensure
    Crawling::Public.define_singleton_method(name) do |**attributes|
      original.call(**attributes)
    end
  end
end
