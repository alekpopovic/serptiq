# frozen_string_literal: true

require "test_helper"

class StaticCrawlConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @at = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "static-crawl-db-owner")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "static-crawl-db-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property, at: @at)
    @scan = run_scan_to(@scan, "running", at: @at)
    @item = discover(@scan, "https://example.com/")
    @lease = Crawling::Public.lease_frontier(
      worker_id: "static-db-owner", limit: 1,
      organization_id: @scan.organization_id, scan_id: @scan.id,
      clock: -> { @at + 1.minute }
    ).sole
    @store = TestSupport::FakeArtifactStore.new
  end

  test "exact artifact reference rejects a cross-tenant fetch result" do
    foreign = create_organization_for(slug: "static-crawl-db-foreign")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    project = create_project_for(foreign, slug: "static-crawl-db-foreign-project")
    property = create_property_for(foreign, project: project)
    scan = create_scan_for(foreign, project: project, property: property, at: @at)
    scan = run_scan_to(scan, "running", at: @at)
    foreign_artifact = capture_artifact(foreign, project, property, scan)

    error = assert_database_rejects do
      Crawling::CrawlFetchResult.insert!(
        fetch_attributes(artifact_id: foreign_artifact.artifact_id)
      )
    end

    assert_match(/fk_crawl_fetch_results_exact_artifact/, error.message)
    assert_equal 0, Crawling::CrawlFetchResult.where(scan_id: @scan.id).count

    owner_artifact = capture_artifact(@owner, @project, @property, @scan)
    evidence_error = assert_database_rejects do
      Crawling::CrawlFetchResult.insert!(
        fetch_attributes(artifact_id: owner_artifact.artifact_id).merge(http_status_code: 500)
      )
    end
    assert_match(/crawl_fetch_results_outcome_shape/, evidence_error.message)
  end

  test "fetch observations are immutable and snapshots retain exact source identity" do
    result, snapshot = create_snapshot_evidence

    fetch_error = assert_database_rejects do
      Crawling::CrawlFetchResult.where(id: result.id).update_all(http_status_code: 204)
    end
    snapshot_error = assert_database_rejects do
      Crawling::PageSnapshot.where(id: snapshot.id).update_all(crawl_url_id: @item.id + 1)
    end

    assert_match(/crawl fetch results are immutable/, fetch_error.message)
    assert_match(/crawl page snapshot identity is immutable/, snapshot_error.message)
    assert_equal 200, result.reload.http_status_code
    assert_equal @item.id, snapshot.reload.crawl_url_id
  end

  test "page facts and directed links enforce exact tenant sources bounds and immutability" do
    _result, snapshot = create_snapshot_evidence
    foreign_identity = page_fact_attributes(snapshot).merge(organization_id: SecureRandom.uuid)
    exact_error = assert_database_rejects do
      Crawling::PageFact.insert!(foreign_identity)
    end
    assert_match(/fk_crawl_page_facts_exact_snapshot/, exact_error.message)

    fact = Crawling::PageFact.create!(page_fact_attributes(snapshot))
    invalid_destination = crawl_link_attributes(snapshot).merge(
      destination_crawl_url_id: @item.id + 100_000
    )
    link_error = assert_database_rejects do
      Crawling::CrawlLink.insert!(invalid_destination)
    end
    assert_match(/fk_crawl_links_same_scan_destination/, link_error.message)
    rel_error = assert_database_rejects do
      Crawling::CrawlLink.insert!(
        crawl_link_attributes(snapshot).merge(rel_tokens: [ "<script>" ])
      )
    end
    assert_match(/crawl_links_evidence_shape/, rel_error.message)

    link = Crawling::CrawlLink.create!(crawl_link_attributes(snapshot))
    fact_error = assert_database_rejects do
      Crawling::PageFact.where(id: fact.id).update_all(title_summary: "rewritten")
    end
    immutable_link_error = assert_database_rejects do
      Crawling::CrawlLink.where(id: link.id).update_all(anchor_summary: "rewritten")
    end
    assert_match(/crawl page facts are immutable/, fact_error.message)
    assert_match(/crawl links are immutable/, immutable_link_error.message)
  end

  private

  def discover(scan, url)
    Crawling::Public.discover_frontier(
      organization_id: scan.organization_id,
      scan_id: scan.id,
      entries: [ Crawling::Public.frontier_entry(url: url, depth: 0, discovery_source: "seed") ],
      clock: -> { @at }
    ).items.sole
  end

  def capture_artifact(owner, project, property, scan)
    Crawling::CaptureArtifact.new(store: @store, clock: -> { @at }).call(
      organization_id: owner.organization.id,
      project_id: project.id,
      property_id: property.id,
      environment_id: scan.environment_id,
      scan_id: scan.id,
      source_type: "crawl_fetch",
      source_id: SecureRandom.uuid,
      kind: "response_body",
      media_type: "text/html",
      filename: "response.html",
      retention_class: "raw_crawl",
      retention_expires_at: @at + 1.day,
      io: StringIO.new("<!doctype html><p>bounded</p>")
    )
  end

  def fetch_attributes(artifact_id:)
    {
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      crawl_url_id: @item.id,
      artifact_id: artifact_id,
      attempt_number: @lease.attempts,
      source_key_digest: Digest::SHA256.hexdigest("static-db-fetch"),
      lease_token_digest: Digest::SHA256.hexdigest(@lease.token),
      request_method: "GET",
      outcome: "succeeded",
      http_status_code: 200,
      final_url: @item.fetch_url,
      final_url_digest: Digest::SHA256.hexdigest(@item.fetch_url),
      media_type: "text/html",
      content_encoding: "identity",
      response_headers: { "content-type" => "text/html" },
      body_sha256: Digest::SHA256.hexdigest("<!doctype html><p>bounded</p>"),
      sniffed_kind: "html",
      request_count: 1,
      retry_count: 0,
      redirect_count: 0,
      duration_ms: 4,
      fetched_at: @at,
      created_at: @at,
      updated_at: @at
    }
  end

  def create_snapshot_evidence
    artifact = capture_artifact(@owner, @project, @property, @scan)
    result = Crawling::CrawlFetchResult.create!(
      fetch_attributes(artifact_id: artifact.artifact_id)
    )
    snapshot = Crawling::PageSnapshot.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      crawl_url_id: @item.id,
      crawl_fetch_result_id: result.id,
      artifact_id: artifact.artifact_id,
      state: "pending",
      next_attempt_at: @at
    )
    [ result, snapshot ]
  end

  def page_fact_attributes(snapshot)
    statuses = Crawling::PageFact::FACT_KEYS.index_with { "absent" }
    {
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      page_snapshot_id: snapshot.id,
      parser_version: Crawling::HtmlPageExtractor::PARSER_VERSION,
      content_sha256: Digest::SHA256.hexdigest("body"),
      fact_digest: Digest::SHA256.hexdigest("facts"),
      parse_status: "parsed",
      parse_error_count: 0,
      element_count: 1,
      effective_base_url: @item.fetch_url,
      title_status: "absent",
      description_status: "absent",
      language_status: "absent",
      fact_statuses: statuses,
      meta_directives: [],
      headings: [],
      canonicals: [],
      hreflangs: [],
      images: [],
      structured_data_blocks: [],
      counts: {},
      created_at: @at,
      updated_at: @at
    }
  end

  def crawl_link_attributes(snapshot)
    {
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      page_snapshot_id: snapshot.id,
      source_crawl_url_id: @item.id,
      destination_crawl_url_id: @item.id,
      destination_url: @item.normalized_url,
      destination_url_digest: @item.normalized_url_digest,
      normalization_version: @item.normalization_version,
      destination_host_digest: @item.host_digest,
      classification: "internal",
      scope_status: "allowed",
      scope_reason: "same_origin",
      discovery_status: "linked",
      source_locator: "/html/body/a",
      rel_tokens: [],
      anchor_summary: "Home",
      anchor_digest: Digest::SHA256.hexdigest("Home"),
      nofollow: false,
      occurrence_count: 1,
      nofollow_count: 0,
      edge_digest: Digest::SHA256.hexdigest("edge"),
      discovered_at: @at,
      created_at: @at,
      updated_at: @at
    }
  end

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true, &block)
    end
  end
end
