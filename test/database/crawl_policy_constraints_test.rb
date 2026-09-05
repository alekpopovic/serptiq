# frozen_string_literal: true

require "test_helper"

class CrawlPolicyConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "crawl-policy-constraints")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    enable_crawl_policy(@owner)
    @project = create_project_for(@owner, slug: "policy-constraints-project")
    @property = create_property_for(@owner, project: @project)
    @environment = @property.environments.sole
    @version = Crawling::Public.configure_policy(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      attributes: valid_crawl_policy_attributes(origin: @environment.origin)
    )
  end

  test "database rejects mutable versions and snapshots" do
    assert_database_rejects do
      Crawling::PolicyVersion.where(id: @version.id).update_all(max_depth: 6)
    end

    scan = create_scan_for(
      @owner, project: @project, property: @property, environment: @environment
    )
    snapshot = Crawling::Public.snapshot_for_scan(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      scan_id: scan.id
    )
    assert_database_rejects do
      Crawling::PolicySnapshot.where(id: snapshot.id).delete_all
    end
  end

  test "database rejects invalid robot and rendering shapes" do
    attributes = @version.attributes.except("id")
      .merge("version" => 2, "robots_behavior" => "ignore")
    assert_database_rejects do
      Crawling::PolicyVersion.insert!(attributes)
    end

    attributes = @version.attributes.except("id")
      .merge("version" => 2, "rendering_sample_percent" => 0, "max_rendered_pages" => 1)
    assert_database_rejects do
      Crawling::PolicyVersion.insert!(attributes)
    end
  end

  private

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      Crawling::PolicyVersion.transaction(requires_new: true, &block)
    end
  end
end
