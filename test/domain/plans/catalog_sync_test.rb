# frozen_string_literal: true

require "test_helper"

class PlansCatalogSyncTest < ActiveSupport::TestCase
  test "dry run reports all additions without database or audit writes" do
    result = Plans::Public.sync_catalog(dry_run: true)

    assert_predicate result, :dry_run?
    assert_equal 10, result.change_count
    assert_equal 0, Plans::Plan.count
    assert_equal 0, Plans::PlanVersion.count
    refute Auditing::AuditEvent.exists?(action: "plan.catalog_synchronized")
  end

  test "sync is idempotent and preserves stable identifiers" do
    first = Plans::Public.sync_catalog
    plan_ids = Plans::Plan.order(:display_order).pluck(:key, :id)
    version_ids = Plans::PlanVersion.joins(:plan).order("plans.display_order").pluck(:id)

    second = Plans::Public.sync_catalog

    assert_equal 10, first.change_count
    assert_equal 0, second.change_count
    assert_equal 5, Plans::Plan.count
    assert_equal 5, Plans::PlanVersion.count
    assert_equal plan_ids, Plans::Plan.order(:display_order).pluck(:key, :id)
    assert_equal version_ids, Plans::PlanVersion.joins(:plan).order("plans.display_order").pluck(:id)
    assert_equal 1, Auditing::AuditEvent.where(action: "plan.catalog_synchronized").count
  end

  test "draft metadata may sync but a published key and version cannot be overwritten" do
    Plans::Public.sync_catalog
    changed_catalog = catalog_with do |document|
      document.fetch("plans").find { |row| row.fetch("key") == "starter" }["display_name"] = "Starter Preview"
    end

    Plans::Public.sync_catalog(path: changed_catalog)
    version = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    assert_equal "Starter Preview", version.display_name
    publish(version)

    changed_again = catalog_with do |document|
      document.fetch("plans").find { |row| row.fetch("key") == "starter" }["display_name"] = "Starter Rewrite"
    end
    assert_raises(Plans::PublishedVersionImmutable) do
      Plans::Public.sync_catalog(path: changed_again)
    end
    assert_equal "Starter Preview", version.reload.display_name
  end

  private

  def publish(record)
    now = Time.current
    record.update_columns(status: "published", effective_at: now, published_at: now)
  end

  def catalog_with
    document = YAML.safe_load_file(Plans::Catalog::DEFAULT_PATH, permitted_classes: [ Date ], aliases: false)
    yield document
    directory = Pathname(Dir.mktmpdir("plans-sync"))
    path = directory.join("plans.yml")
    path.write(YAML.dump(document))
    @temporary_catalog_directories ||= []
    @temporary_catalog_directories << directory
    path
  end

  teardown do
    Array(@temporary_catalog_directories).each do |directory|
      FileUtils.remove_entry(directory) if directory.exist?
    end
  end
end
