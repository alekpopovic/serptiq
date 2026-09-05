# frozen_string_literal: true

require "test_helper"

class CrawlSitemapConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "sitemap-constraints")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "sitemap-constraints-project")
    @property = create_property_for(
      @owner,
      project: @project,
      configuration: { origin: "https://constraints.example.com" }
    )
    @scan = create_scan_for(@owner, project: @project, property: @property)
    @discovery = Crawling::SitemapDiscovery.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      status: "running",
      started_at: Time.current
    )
    @file = Crawling::SitemapFile.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      sitemap_discovery_id: @discovery.id,
      url: "https://constraints.example.com/sitemap.xml",
      url_digest: Digest::SHA256.hexdigest("https://constraints.example.com/sitemap.xml"),
      source: "configured",
      index_depth: 0,
      status: "pending"
    )
  end

  test "database enforces exact tenant graph counter and lifecycle invariants" do
    assert_database_rejects do
      Crawling::SitemapDiscovery.where(id: @discovery.id).update_all(
        documents_processed_count: 1
      )
    end
    assert_database_rejects do
      Crawling::SitemapFile.where(id: @file.id).update_all(organization_id: SecureRandom.uuid)
    end
    assert_database_rejects do
      Crawling::SitemapFile.insert!(
        @file.attributes.except("id").merge(
          "url" => "https://constraints.example.com/foreign.xml",
          "url_digest" => "b" * 64,
          "scan_id" => SecureRandom.uuid
        )
      )
    end

    @file.update!(
      status: "fetched",
      document_kind: "urlset",
      final_url: @file.url,
      http_status: 200,
      retrieved_at: Time.current,
      artifact_sha256: "a" * 64,
      content_type: "application/xml",
      gzip: false,
      compressed_bytes: 10,
      decompressed_bytes: 10,
      redirect_count: 0,
      parser_version: 1
    )
    assert_database_rejects do
      Crawling::SitemapFile.where(id: @file.id).update_all(entry_count: 1)
    end
    assert_database_rejects do
      Crawling::SitemapFile.where(id: @file.id).delete_all
    end
  end

  test "entry rows reject cross-scan children and remain immutable" do
    entry = Crawling::SitemapEntry.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      sitemap_file_id: @file.id,
      entry_index: 1,
      entry_kind: "page",
      location_url: "https://constraints.example.com/page",
      location_digest: Digest::SHA256.hexdigest("https://constraints.example.com/page"),
      normalization_version: 2,
      scope_status: "in_scope",
      scope_reason: "same_origin",
      relationship_status: "frontier_limit",
      created_at: Time.current
    )

    assert_database_rejects do
      Crawling::SitemapEntry.where(id: entry.id).update_all(scope_reason: "host_out_of_scope")
    end
    assert_database_rejects do
      Crawling::SitemapEntry.where(id: entry.id).delete_all
    end
    assert_database_rejects do
      Crawling::SitemapEntry.insert!(
        entry.attributes.except("id").merge(
          "entry_index" => 2,
          "location_url" => "https://constraints.example.com/other",
          "location_digest" => "c" * 64,
          "scan_id" => SecureRandom.uuid
        )
      )
    end
  end

  private

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      ApplicationRecord.transaction(requires_new: true, &block)
    end
  end
end
