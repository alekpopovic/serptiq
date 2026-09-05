# frozen_string_literal: true

require "test_helper"

class ScanConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "scan-constraints")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    enable_crawl_policy(@owner)
    @project = create_project_for(@owner, slug: "scan-constraints-project")
    @property = create_property_for(@owner, project: @project)
    @environment = @property.environments.sole
    @scan = create_scan_for(@owner, project: @project, property: @property)
  end

  test "database trigger rejects scan snapshot and provenance mutation" do
    assert_database_rejects do
      Crawling::Scan.where(id: @scan.id).update_all(
        settings_snapshot: { "max_urls" => 999 }
      )
    end
    assert_database_rejects do
      Crawling::Scan.where(id: @scan.id).update_all(engine_version: "crawler-2.0.0")
    end

    assert_equal 20, @scan.reload.settings_snapshot.fetch("max_urls")
    assert_equal "crawler-1.0.0", @scan.engine_version
  end

  test "database rejects inconsistent counters and lifecycle timestamps" do
    assert_database_rejects do
      Crawling::Scan.where(id: @scan.id).update_all(
        urls_discovered_count: 1,
        urls_processed_count: 1,
        urls_succeeded_count: 0
      )
    end
    assert_database_rejects do
      Crawling::Scan.where(id: @scan.id).update_all(status: "completed", completed_at: Time.current)
    end
  end

  test "database composite foreign keys reject cross-tenant targets and baselines" do
    foreign = create_organization_for(slug: "scan-constraints-foreign")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    foreign_project = create_project_for(foreign, slug: "scan-constraints-foreign-project")
    foreign_property = create_property_for(foreign, project: foreign_project)

    attributes = @scan.attributes.except("id", "created_at", "updated_at", "lock_version")
      .merge("id" => SecureRandom.uuid, "environment_id" => foreign_property.environments.sole.id)
    assert_database_rejects { Crawling::Scan.insert!(attributes) }

    baseline = run_scan_to(@scan, "completed")
    other_property = create_property_for(@owner, project: @project)
    other = create_scan_for(@owner, project: @project, property: other_property)
    attributes = other.attributes.except("id", "created_at", "updated_at", "lock_version")
      .merge("id" => SecureRandom.uuid, "baseline_scan_id" => baseline.id)
    assert_database_rejects { Crawling::Scan.insert!(attributes) }
  end

  test "scan events are append-only and policy snapshots require an exact scan" do
    event = @scan.events.sole
    assert_database_rejects do
      Crawling::ScanEvent.where(id: event.id).update_all(to_status: "failed")
    end
    assert_database_rejects do
      Crawling::ScanEvent.where(id: event.id).delete_all
    end

    Crawling::Public.configure_policy(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      attributes: valid_crawl_policy_attributes(origin: @environment.origin)
    )
    assert_database_rejects do
      Crawling::PolicySnapshot.create!(
        scan_id: SecureRandom.uuid,
        organization_id: @owner.organization.id,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        crawl_policy_version_id: Crawling::PolicyVersion.last.id,
        policy_version: 1,
        configuration: { "max_urls" => 1 },
        configuration_digest: Digest::SHA256.hexdigest(JSON.generate({ "max_urls" => 1 })),
        created_at: Time.current
      )
    end
  end

  private

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      Crawling::Scan.transaction(requires_new: true, &block)
    end
  end
end
