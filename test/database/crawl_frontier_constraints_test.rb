# frozen_string_literal: true

require "test_helper"

class CrawlFrontierConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "frontier-constraints")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "frontier-constraints-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property)
    @scan = run_scan_to(@scan, "queued")
    @item = discover(@scan, "https://example.com/first")
  end

  test "database enforces per-scan URL identity and immutable discovery provenance" do
    assert_database_rejects do
      Crawling::CrawlUrl.where(id: @item.id).update_all(normalized_url: "https://example.com/changed")
    end
    assert_equal "https://example.com/first", @item.reload.normalized_url

    duplicate = @item.attributes.except("id", "created_at", "updated_at")
    assert_database_rejects { Crawling::CrawlUrl.insert!(duplicate) }
    assert_database_rejects do
      Crawling::CrawlUrl.where(id: @item.id).update_all(
        state: "succeeded",
        next_attempt_at: nil,
        completed_at: Time.current,
        last_lease_token_digest: "a" * 64,
        last_lease_outcome: "succeeded"
      )
    end
    assert_database_rejects { Crawling::CrawlUrl.where(id: @item.id).delete_all }
  end

  test "composite foreign keys reject cross-tenant scans and cross-scan discovery parents" do
    foreign = create_organization_for(slug: "frontier-constraints-foreign")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    project = create_project_for(foreign, slug: "frontier-constraints-foreign-project")
    property = create_property_for(foreign, project: project)
    scan = create_scan_for(foreign, project: project, property: property)
    scan = run_scan_to(scan, "queued")
    foreign_item = discover(scan, "https://foreign.example.com/first")

    mismatched = @item.attributes.except("id", "created_at", "updated_at").merge(
      "normalized_url" => "https://example.com/mismatch",
      "normalized_url_digest" => Digest::SHA256.hexdigest("mismatch"),
      "scan_id" => scan.id
    )
    assert_database_rejects { Crawling::CrawlUrl.insert!(mismatched) }

    child = Crawling::FrontierEntry.new(
      url: "https://example.com/child",
      depth: 1,
      discovery_source: "link",
      discovered_from_id: foreign_item.id
    )
    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.discover_frontier(
        organization_id: @scan.organization_id,
        scan_id: @scan.id,
        entries: [ child ]
      )
    end
  end

  private

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      Crawling::CrawlUrl.transaction(requires_new: true, &block)
    end
  end

  def discover(scan, url)
    Crawling::Public.discover_frontier(
      organization_id: scan.organization_id,
      scan_id: scan.id,
      entries: [ Crawling::FrontierEntry.new(url: url, depth: 0, discovery_source: "seed") ],
      clock: -> { Time.current.change(usec: 0) }
    ).items.sole
  end
end
