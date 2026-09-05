# frozen_string_literal: true

require "test_helper"
require "stringio"
require "zlib"

class CrawlingSitemapDiscoveryTest < ActiveSupport::TestCase
  FIXTURES = Rails.root.join("test/fixtures/files/crawling")

  FakeRetriever = Struct.new(:responses, :calls, :clock, keyword_init: true) do
    def call(origin:, url:)
      calls << { origin: origin.respond_to?(:origin) ? origin.origin : origin.to_s, url: url }
      value = responses.fetch(url) { response(url, 404, "missing") }
      value.respond_to?(:call) ? value.call : value
    end

    def response(url, status, body, content_type: "application/xml")
      state = status.between?(200, 299) ? "fetched" : "unavailable"
      Crawling::SitemapRetrieval.new(
        status: state,
        http_status: status,
        retrieved_at: clock.call,
        artifact_sha256: Digest::SHA256.hexdigest(body),
        source_url: url,
        final_url: url,
        redirect_count: 0,
        content_type: content_type,
        body: body
      )
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "sitemap-discovery")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "sitemap-project")
    @property = create_property_for(
      @owner,
      project: @project,
      configuration: { origin: "https://example.com" }
    )
    @scan = create_scan_for(
      @owner,
      project: @project,
      property: @property,
      at: @now - 2.seconds,
      settings_snapshot: {
        "sitemap_urls" => [ "https://example.com/sitemap-index.xml" ],
        "max_urls" => 20,
        "max_depth" => 5,
        "query_handling" => "tracking_only",
        "query_parameter_allowlist" => [],
        "query_parameter_denylist" => [],
        "robots_behavior" => "respect"
      }
    )
    @scan = run_scan_to(@scan, "queued", at: @now - 1.second)
  end

  test "discovers configured robots well-known index and gzip files with a bounded graph and meter" do
    create_robots_snapshot!(
      "https://example.com/sitemap-index.xml",
      "https://outside.example.net/hostile.xml"
    )
    loop_xml = <<~XML
      <sitemapindex xmlns="#{Crawling::SitemapParser::NAMESPACE}">
        <sitemap><loc>https://example.com/sitemap-index.xml</loc></sitemap>
      </sitemapindex>
    XML
    retriever = fake_retriever(
      "https://example.com/sitemap-index.xml" => fixture("sitemap_index.xml"),
      "https://example.com/sitemap-pages.xml.gz" => gzip(fixture("sitemap_urlset.xml")),
      "https://example.com/sitemap-loop.xml" => loop_xml
    )
    service = Crawling::DiscoverSitemaps.new(retriever: retriever, clock: -> { @now })

    discovery = service.call(organization_id: @scan.organization_id, scan_id: @scan.id)
    replay = service.call(organization_id: @scan.organization_id, scan_id: @scan.id)

    assert_equal discovery.id, replay.id
    file_evidence = discovery.sitemap_files.order(:url).pluck(:url, :status, :error_code)
    assert_equal "partially_completed", discovery.status, file_evidence.inspect
    assert_equal 5, discovery.documents_discovered_count
    assert_equal 5, discovery.documents_processed_count
    assert_equal 3, discovery.documents_succeeded_count
    assert_equal 2, discovery.documents_failed_count
    assert_equal 4, discovery.fetch_attempt_count
    assert_equal 4, discovery.metered_fetch_count
    assert_equal 4, retriever.calls.length
    refute_includes retriever.calls.map { |call| call.fetch(:url) }, "https://outside.example.net/hostile.xml"

    outside = Crawling::SitemapFile.find_by!(scan_id: @scan.id, source: "robots")
    assert_equal "rejected", outside.status
    assert_equal "host_out_of_scope", outside.error_code
    gzip_file = Crawling::SitemapFile.find_by!(url: "https://example.com/sitemap-pages.xml.gz")
    assert gzip_file.gzip
    assert_equal "urlset", gzip_file.document_kind
    loop_entry = Crawling::SitemapEntry.find_by!(relationship_status: "circular")
    assert_equal "sitemap", loop_entry.entry_kind

    assert_equal 2, Crawling::CrawlUrl.where(scan_id: @scan.id).count
    assert_equal 2, discovery.frontier_inserted_count
    products = Crawling::CrawlUrl.find_by!(scan_id: @scan.id, normalized_url: "https://example.com/products?id=7")
    assert_equal "https://example.com/products?id=7&utm_source=sitemap", products.fetch_url
    assert_equal "sitemap", products.discovery_source
    assert_equal 4, gzip_file.entry_count
    assert_equal 3, gzip_file.entries.count
    assert_includes gzip_file.warnings.map { |warning| warning.fetch("code") }, "duplicate_location"
    assert_includes gzip_file.warnings.map { |warning| warning.fetch("code") }, "invalid_lastmod"
    outside_entry = gzip_file.entries.find_by!(scope_status: "out_of_scope")
    assert_equal "https://outside.example.net/page", outside_entry.location_url
    assert_equal "host_out_of_scope", outside_entry.scope_reason
    lastmod = gzip_file.entries.find_by!(location_url: "https://example.com/docs")
    assert_equal "date", lastmod.lastmod_precision
    assert_equal Time.utc(2026, 8, 20), lastmod.lastmod_at
  end

  test "bounds index recursion and records the rejected relationship without fetching the child" do
    retriever = fake_retriever(
      "https://example.com/sitemap-index.xml" => fixture("sitemap_index.xml")
    )
    bounded_settings = Rails.application.config.x.searchops.to_h.merge(
      crawler_sitemap_max_index_depth: 0,
      crawler_sitemap_well_known_enabled: false
    )
    discovery = Crawling::DiscoverSitemaps.new(
      retriever: retriever,
      clock: -> { @now },
      settings: bounded_settings
    ).call(organization_id: @scan.organization_id, scan_id: @scan.id)

    file_evidence = discovery.sitemap_files.order(:url).pluck(:url, :status, :error_code)
    assert_equal "partially_completed", discovery.status, file_evidence.inspect
    assert_equal 1, discovery.documents_discovered_count
    assert_equal 1, discovery.fetch_attempt_count
    assert_equal 2, Crawling::SitemapEntry.where(
      scan_id: @scan.id, relationship_status: "depth_rejected"
    ).count
    assert_equal [ "https://example.com/sitemap-index.xml" ], retriever.calls.map { |call| call.fetch(:url) }
  end

  test "resumes a running discovery after persisted frontier and entry side effects" do
    discovery = Crawling::SitemapDiscovery.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      status: "running",
      started_at: @now - 1.second
    )
    file = Crawling::SitemapFile.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      sitemap_discovery_id: discovery.id,
      url: "https://example.com/sitemap-index.xml",
      url_digest: Crawling::Public.normalize_url(
        url: "https://example.com/sitemap-index.xml"
      ).identity_digest,
      source: "configured",
      index_depth: 0,
      status: "pending"
    )
    frontier = Crawling::Public.discover_frontier(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      entries: [
        Crawling::FrontierEntry.new(
          url: "https://example.com/resumed",
          depth: 0,
          discovery_source: "sitemap"
        )
      ],
      clock: -> { @now }
    ).items.sole
    Crawling::SitemapEntry.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      sitemap_file_id: file.id,
      entry_index: 1,
      entry_kind: "page",
      location_url: "https://example.com/resumed",
      location_digest: frontier.normalized_url_digest,
      normalization_version: 2,
      scope_status: "in_scope",
      scope_reason: "same_origin",
      relationship_status: "frontier_inserted",
      crawl_url_id: frontier.id,
      created_at: @now
    )
    xml = <<~XML
      <urlset xmlns="#{Crawling::SitemapParser::NAMESPACE}">
        <url><loc>https://example.com/resumed</loc></url>
      </urlset>
    XML
    retriever = fake_retriever("https://example.com/sitemap-index.xml" => xml)

    resumed = Crawling::DiscoverSitemaps.new(
      retriever: retriever,
      clock: -> { @now }
    ).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      include_well_known: false
    )

    assert_equal "completed", resumed.status
    assert_equal 1, resumed.frontier_inserted_count
    assert_equal 1, Crawling::SitemapEntry.where(sitemap_file_id: file.id).count
    assert_equal "frontier_inserted", file.entries.sole.relationship_status
    assert_equal 1, retriever.calls.length
  end

  test "fails closed across tenants" do
    foreign = create_organization_for(slug: "sitemap-discovery-foreign")

    error = assert_raises(Crawling::AccessDenied) do
      Crawling::Public.discover_sitemaps(
        organization_id: foreign.organization.id,
        scan_id: @scan.id,
        include_well_known: false,
        clock: -> { @now }
      )
    end

    assert_equal "sitemap_scope_unavailable", error.reason_code
    assert_nil Crawling::SitemapDiscovery.find_by(scan_id: @scan.id)
  end

  private

  def create_robots_snapshot!(*urls)
    Crawling::RobotsSnapshot.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      origin: "https://example.com",
      origin_digest: Digest::SHA256.hexdigest("https://example.com"),
      source_url: "https://example.com/robots.txt",
      final_url: "https://example.com/robots.txt",
      retrieval_status: "fetched",
      http_status: 200,
      retrieved_at: @now,
      artifact_sha256: "a" * 64,
      parser_version: 1,
      redirect_count: 0,
      groups: [],
      sitemap_urls: urls,
      warnings: [],
      malformed: false
    )
  end

  def fake_retriever(responses)
    object = FakeRetriever.new(responses: {}, calls: [], clock: -> { @now })
    object.responses = responses.to_h do |url, body|
      content_type = url.end_with?(".gz") ? "application/gzip" : "application/xml"
      [ url, object.response(url, 200, body, content_type: content_type) ]
    end
    object
  end

  def fixture(name)
    FIXTURES.join(name).binread
  end

  def gzip(value)
    output = StringIO.new
    Zlib::GzipWriter.wrap(output) { |writer| writer.write(value) }
    output.string
  end
end
