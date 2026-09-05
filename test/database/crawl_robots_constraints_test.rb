# frozen_string_literal: true

require "test_helper"

class CrawlRobotsConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    owner = create_organization_for(slug: "robots-constraints")
    enable_project_limit(owner)
    enable_property_limits(owner)
    project = create_project_for(owner, slug: "robots-constraints-project")
    property = create_property_for(
      owner,
      project: project,
      configuration: { origin: "https://constraints.example.com" }
    )
    scan = create_scan_for(owner, project: project, property: property)
    @snapshot = Crawling::RobotsSnapshot.create!(
      organization_id: scan.organization_id,
      project_id: scan.project_id,
      property_id: scan.property_id,
      environment_id: scan.environment_id,
      scan_id: scan.id,
      origin: "https://constraints.example.com",
      origin_digest: Digest::SHA256.hexdigest("https://constraints.example.com"),
      source_url: "https://constraints.example.com/robots.txt",
      final_url: "https://constraints.example.com/robots.txt",
      retrieval_status: "fetched",
      http_status: 200,
      retrieved_at: Time.current,
      artifact_sha256: Digest::SHA256.hexdigest("User-agent: *\nAllow: /\n"),
      parser_version: 1,
      redirect_count: 0,
      groups: [],
      sitemap_urls: [],
      warnings: [],
      malformed: false,
      created_at: Time.current
    )
  end

  test "database protects tenant identity uniqueness payload shape and immutability" do
    assert_database_rejects do
      Crawling::RobotsSnapshot.where(id: @snapshot.id).update_all(origin: "https://changed.example.com")
    end
    assert_database_rejects do
      Crawling::RobotsSnapshot.where(id: @snapshot.id).delete_all
    end

    attributes = @snapshot.attributes.except("id")
    assert_database_rejects do
      Crawling::RobotsSnapshot.insert!(attributes)
    end
    assert_database_rejects do
      Crawling::RobotsSnapshot.insert!(
        attributes.merge(
          "scan_id" => SecureRandom.uuid,
          "origin_digest" => "e" * 64
        )
      )
    end
    assert_database_rejects do
      Crawling::RobotsSnapshot.insert!(
        attributes.merge(
          "origin_digest" => "d" * 64,
          "retrieval_status" => "unavailable",
          "http_status" => 200
        )
      )
    end
  end

  private

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      Crawling::RobotsSnapshot.transaction(requires_new: true, &block)
    end
  end
end
