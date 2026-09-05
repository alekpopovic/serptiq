# frozen_string_literal: true

require "test_helper"

class CrawlingHtmlExtractionGraphTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "html-graph-owner")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "html-graph-project")
    @property = create_property_for(
      @owner,
      project: @project,
      configuration: { origin: "https://example.com" }
    )
    @scan = create_scan_for(
      @owner,
      project: @project,
      property: @property,
      at: @now - 1.minute,
      settings_snapshot: {
        "start_urls" => [ "https://example.com/" ],
        "max_urls" => 20,
        "max_depth" => 3,
        "query_handling" => "tracking_only",
        "query_parameter_allowlist" => [],
        "query_parameter_denylist" => [],
        "artifact_retention_days" => 2,
        "robots_behavior" => "respect"
      }
    )
    @scan = run_scan_to(@scan, "running", at: @now - 30.seconds)
    @store = TestSupport::FakeArtifactStore.new
  end

  test "persists immutable facts and deduplicated graph edges then replays idempotently" do
    snapshot = create_snapshot(
      url: "https://example.com/source/index.html",
      depth: 0,
      body: file_fixture("crawling/html/extraction_document.html").binread
    )
    extractor = Crawling::ExtractStaticPageLinks.new(clock: -> { @now }, store: @store)

    completed = extractor.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: snapshot.id,
      worker_id: "html-extract-1"
    )

    assert completed.completed?
    fact = snapshot.reload.page_fact
    assert_equal Crawling::HtmlPageExtractor::PARSER_VERSION, fact.parser_version
    assert_equal snapshot.fetch_result.body_sha256, fact.content_sha256
    assert_equal "Search & Discovery Guide", fact.title_summary
    assert_equal "malformed", fact.fact_statuses.fetch("structured_data")
    assert_equal 2, fact.counts.fetch("frontier_linked")
    assert_equal 3, snapshot.crawl_links.count
    about = snapshot.crawl_links.find_by!(destination_url: "https://example.com/about?b=2")
    assert_equal "linked", about.discovery_status
    assert_equal 2, about.occurrence_count
    assert_equal 1, about.nofollow_count
    assert about.nofollow?
    external = snapshot.crawl_links.external.sole
    assert_nil external.destination_crawl_url_id
    assert_equal "not_applicable", external.discovery_status

    assert_no_difference [ "Crawling::PageFact.count", "Crawling::CrawlLink.count",
      "Crawling::CrawlUrl.count" ] do
      assert extractor.call(
        organization_id: @scan.organization_id,
        scan_id: @scan.id,
        page_snapshot_id: snapshot.id,
        worker_id: "html-extract-replay"
      ).completed?
    end
  end

  test "records unavailable facts after bounded terminal extraction failure" do
    snapshot = create_snapshot(
      url: "https://example.com/huge",
      depth: 0,
      body: "x" * (Crawling::HtmlPageExtractor::MAX_HTML_BYTES + 1),
      maximum_extraction_attempts: 1
    )

    result = Crawling::ExtractStaticPageLinks.new(clock: -> { @now }, store: @store).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: snapshot.id,
      worker_id: "html-extract-limit"
    )

    assert result.failed?
    assert_equal "extraction_body_too_large", result.last_failure_category
    assert_equal "unavailable", result.page_fact.parse_status
    assert result.page_fact.fact_statuses.values.all? { |status| status == "unavailable" }
    assert_empty result.crawl_links
  end

  test "refuses to attach facts parsed from content that does not match the fetch evidence" do
    snapshot = create_snapshot(
      url: "https://example.com/integrity",
      depth: 0,
      body: "<!doctype html><title>Expected</title>"
    )
    extraction = Crawling::HtmlPageExtractor.new.call(
      body: "<!doctype html><title>Substituted</title>",
      document_url: snapshot.fetch_result.final_url,
      scope: Crawling::Public.url_scope_for_scan(
        organization_id: @scan.organization_id,
        scan_id: @scan.id
      ),
      depth: 0,
      settings: @scan.settings_snapshot
    )

    error = assert_raises(Crawling::Conflict) do
      Crawling::PersistHtmlExtraction.new.call(
        snapshot: snapshot,
        extraction: extraction,
        destinations: {},
        frontier_linked_count: 0
      )
    end

    assert_equal "page_content_hash_mismatch", error.reason_code
    assert_nil snapshot.page_fact
    assert_empty snapshot.crawl_links
  end

  test "recovery keeps the linked destination count stable after discovery committed first" do
    snapshot = create_snapshot(
      url: "https://example.com/source/index.html",
      depth: 0,
      body: file_fixture("crawling/html/extraction_document.html").binread
    )
    failing_persister = Object.new
    failing_persister.define_singleton_method(:call) { |**| raise "simulated persistence crash" }
    first = Crawling::ExtractStaticPageLinks.new(
      clock: -> { @now },
      store: @store,
      persister: failing_persister
    ).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: snapshot.id,
      worker_id: "html-before-persist-crash"
    )

    assert first.pending?
    assert_equal 3, Crawling::CrawlUrl.where(scan_id: @scan.id).count
    recovered = Crawling::ExtractStaticPageLinks.new(clock: -> { @now + 1.minute }, store: @store).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: snapshot.id,
      worker_id: "html-after-persist-crash"
    )

    assert recovered.completed?
    assert_equal 2, recovered.discovered_links_count
    assert_equal 2, recovered.page_fact.counts.fetch("frontier_linked")
    assert_equal 3, recovered.crawl_links.count
  end

  test "builds tenant-exact broken orphan and depth read models" do
    root = create_snapshot(
      url: "https://example.com/source/index.html",
      depth: 0,
      body: file_fixture("crawling/html/extraction_document.html").binread
    )
    Crawling::ExtractStaticPageLinks.new(clock: -> { @now }, store: @store).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: root.id,
      worker_id: "html-graph-root"
    )
    broken = Crawling::CrawlUrl.find_by!(
      scan_id: @scan.id,
      normalized_url_digest: Crawling::Public.normalize_url(
        url: "https://example.com/about?b=2", query_handling: "tracking_only"
      ).identity_digest
    )
    fail_frontier_row(broken)
    orphan = create_snapshot(
      url: "https://example.com/orphan",
      depth: 2,
      body: "<!doctype html><title>Orphan</title>",
      state: "completed"
    )

    graph = Crawling::Public.link_graph(
      organization_id: @scan.organization_id,
      scan_id: @scan.id
    )

    assert_equal 2, graph.node_count
    assert_equal 2, graph.internal_edge_count
    assert_equal 1, graph.external_edge_count
    assert_equal [ broken.id ], graph.broken_destination_crawl_url_ids
    assert_equal [ orphan.crawl_url_id ], graph.orphan_crawl_url_ids
    assert_equal 2, graph.maximum_internal_depth
    assert_equal({ 0 => 1, 2 => 1 }, graph.depth_counts)

    foreign = create_organization_for(slug: "html-graph-foreign")
    error = assert_raises(Crawling::AccessDenied) do
      Crawling::Public.link_graph(
        organization_id: foreign.organization.id,
        scan_id: @scan.id
      )
    end
    assert_equal "link_graph_scope_unavailable", error.reason_code
  end

  private

  def create_snapshot(url:, depth:, body:, state: "pending", maximum_extraction_attempts: 3)
    entry = Crawling::Public.frontier_entry(
      url: url,
      depth: depth,
      discovery_source: depth.zero? ? "seed" : "link",
      query_handling: "tracking_only"
    )
    item = Crawling::Public.discover_frontier(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      entries: [ entry ],
      clock: -> { @now }
    ).items.sole
    artifact = Crawling::CaptureArtifact.new(store: @store, clock: -> { @now }).call(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      source_type: "crawl_fetch",
      source_id: SecureRandom.uuid,
      kind: "response_body",
      media_type: "text/html",
      filename: "response.html",
      retention_class: "raw_crawl",
      retention_expires_at: @now + 1.day,
      io: StringIO.new(body)
    )
    token = SecureRandom.hex(32)
    item.update!(attempts: 1)
    result = create_crawl_fetch_result_for(
      scan: @scan,
      crawl_url: item,
      lease_token: token,
      at: @now,
      body: body,
      artifact_id: artifact.artifact_id
    )
    item.update!(
      state: "succeeded",
      next_attempt_at: nil,
      last_lease_token_digest: Digest::SHA256.hexdigest(token),
      last_lease_outcome: "succeeded",
      fetch_result_id: result.id,
      http_status_code: 200,
      completed_at: @now
    )
    attributes = {
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      crawl_url_id: item.id,
      crawl_fetch_result_id: result.id,
      artifact_id: artifact.artifact_id,
      state: state,
      maximum_extraction_attempts: maximum_extraction_attempts
    }
    if state == "pending"
      attributes[:next_attempt_at] = @now
    else
      attributes[:finished_at] = @now
      attributes[:discovery_parser_version] = Crawling::HtmlPageExtractor::PARSER_VERSION
    end
    Crawling::PageSnapshot.create!(attributes)
  end

  def fail_frontier_row(item)
    token = SecureRandom.hex(32)
    item.update!(
      state: "failed",
      attempts: 1,
      next_attempt_at: nil,
      last_lease_token_digest: Digest::SHA256.hexdigest(token),
      last_lease_outcome: "failed",
      last_failure_category: "http_500",
      completed_at: @now
    )
  end
end
