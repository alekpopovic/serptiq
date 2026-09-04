# frozen_string_literal: true

require "test_helper"

class AdministrationPlanCatalogConsistencyTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    @publisher = create_identity_user(display_name: "Catalog Consistency Operator")
    Plans::CatalogAccessGrant.create!(
      user_id: @publisher.id,
      permission: "plan_catalog.publish",
      granted_at: Time.current
    )
    authorization = Plans::Public.authorize_catalog!(user: @publisher, permission: "plan_catalog.publish")
    @starter = publish_catalog_version(plan_key: "starter", version: 1, authorization: authorization)
  end

  test "report compares YAML database snapshots and required provider mapping metadata" do
    missing = Administration::Public.plan_catalog_consistency(environment: "test")
    assert_includes missing.issues, "starter v1: missing test monthly provider mapping"
    assert_includes missing.issues, "starter v1: missing test annual provider mapping"

    create_mapping("monthly", "variant-starter-monthly")
    create_mapping("annual", "variant-starter-annual")
    complete = Administration::Public.plan_catalog_consistency(environment: "test")

    assert_predicate complete, :consistent?
  end

  test "mismatched mapping and database drift are reported without provider identifiers in plan identity" do
    Billing::PlanProviderMapping.create!(
      plan_version_id: @starter.id,
      provider: "sandbox",
      environment: "test",
      currency: "USD",
      billing_interval: "monthly",
      provider_variant_id: "opaque-variant"
    )
    record = Plans::PlanVersion.find(@starter.id)
    Plans::PlanVersion.where(id: record.id).update_all(status: "retired", retired_at: Time.current)

    report = Administration::Public.plan_catalog_consistency(environment: "test")

    assert report.issues.any? { |issue| issue.include?("currency or interval differs") }
    snapshot = Plans::Public.version_snapshot(id: @starter.id)
    assert_equal "starter", snapshot.plan_key
    refute_respond_to snapshot, :provider_variant_id
  end

  private

  def create_mapping(interval, variant)
    Billing::PlanProviderMapping.create!(
      plan_version_id: @starter.id,
      provider: "sandbox",
      environment: "test",
      currency: "EUR",
      billing_interval: interval,
      provider_variant_id: variant
    )
  end
end
