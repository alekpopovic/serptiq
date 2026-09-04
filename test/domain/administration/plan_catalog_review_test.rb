# frozen_string_literal: true

require "test_helper"

class AdministrationPlanCatalogReviewTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    @starter = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
  end

  test "diff snapshots additions changes removals and affected active subscribers" do
    baseline_entitlements = @starter.entitlements_snapshot.deep_dup
    baseline_entitlements.delete("reports.pdf")
    baseline_entitlements["legacy.flag"] = true
    now = Time.current
    @starter.update_columns(
      entitlements_snapshot: baseline_entitlements,
      status: "published",
      effective_at: now,
      published_at: now
    )
    organization = create_organization_for(name: "Affected Subscriber", slug: "affected-subscriber").organization
    Billing::Public.create_subscription_reference(
      organization_id: organization.id,
      plan_version_id: @starter.id,
      billing_interval: "monthly"
    )
    path = version_two_catalog(monthly_price: 45)
    Plans::Public.sync_catalog(path: path)

    entry = Administration::Public.plan_catalog_review(path: path).entry_for(plan_key: "starter", version: 2)

    assert_equal "version_bump", entry.kind
    assert_predicate entry, :publishable?
    assert_equal 1, entry.affected_subscriber_count
    assert_equal [ "entitlements.reports.pdf" ], entry.additions.map(&:path)
    assert_equal [ "entitlements.legacy.flag" ], entry.removals.map(&:path)
    assert_includes entry.changes.map(&:path), "monthly_price_cents"
    assert_equal "PUBLISH starter VERSION 2 AFTER 1", entry.publication_confirmation
    assert_empty entry.database_drift
  end

  test "same-version published changes demand a bump and out-of-sync drafts cannot publish" do
    now = Time.current
    @starter.update_columns(status: "published", effective_at: now, published_at: now)
    same_version = catalog_with do |document|
      starter_row(document)["monthly_price_eur"] = 45
    end

    same_entry = Administration::Public.plan_catalog_review(path: same_version)
      .entry_for(plan_key: "starter", version: 1)
    assert_predicate same_entry, :version_bump_required?
    refute_predicate same_entry, :publishable?

    next_version = version_two_catalog(monthly_price: 45)
    Plans::Public.sync_catalog(path: next_version)
    changed_after_sync = catalog_with do |document|
      row = starter_row(document)
      row["version"] = 2
      row["monthly_price_eur"] = 49
    end
    draft_entry = Administration::Public.plan_catalog_review(path: changed_after_sync)
      .entry_for(plan_key: "starter", version: 2)
    assert_equal "draft_out_of_sync", draft_entry.kind
    assert_includes draft_entry.database_drift.map(&:path), "monthly_price_cents"
    refute_predicate draft_entry, :publishable?
  end

  test "draft versions absent from YAML are reported as removals" do
    attributes = @starter.attributes.except("id", "created_at", "updated_at", "lock_version")
      .merge("version" => 2)
    Plans::PlanVersion.create!(attributes)

    review = Administration::Public.plan_catalog_review

    assert_equal [ "starter v2" ], review.orphaned_draft_versions
  end

  private

  def version_two_catalog(monthly_price:)
    catalog_with do |document|
      row = starter_row(document)
      row["version"] = 2
      row["monthly_price_eur"] = monthly_price
    end
  end

  def starter_row(document)
    document.fetch("plans").find { |row| row.fetch("key") == "starter" }
  end

  def catalog_with
    document = YAML.safe_load_file(Plans::Catalog::DEFAULT_PATH, permitted_classes: [ Date ], aliases: false)
    yield document
    directory = Pathname(Dir.mktmpdir("catalog-review"))
    path = directory.join("plans.yml")
    path.write(YAML.dump(document))
    @temporary_directories ||= []
    @temporary_directories << directory
    path
  end

  teardown do
    Array(@temporary_directories).each do |directory|
      FileUtils.remove_entry(directory) if directory.exist?
    end
  end
end
