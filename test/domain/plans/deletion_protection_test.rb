# frozen_string_literal: true

require "test_helper"

class PlansDeletionProtectionTest < ActiveSupport::TestCase
  setup { Plans::Public.sync_catalog }

  test "stable plan rows cannot be deleted even after their unreferenced draft is removed" do
    plan = Plans::Plan.find_by!(key: "enterprise")
    plan.versions.first.destroy!

    assert_raises(ActiveRecord::RecordNotDestroyed) { plan.destroy! }
    assert_raises(ActiveRecord::StatementInvalid) do
      Plans::Plan.transaction(requires_new: true) { Plans::Plan.where(id: plan.id).delete_all }
    end
  end

  test "audit targets protect drafts and published versions are permanently undeletable" do
    draft = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "agency" }, version: 1)
    Auditing::Public.record!(
      action: "plan.draft_reviewed",
      target_type: "PlanVersion",
      target_id: draft.id,
      result: "succeeded",
      metadata: { operation: "review", status: "draft" }
    )
    assert_raises(ActiveRecord::StatementInvalid) do
      Plans::PlanVersion.transaction(requires_new: true) do
        Plans::PlanVersion.where(id: draft.id).delete_all
      end
    end

    published = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "free" }, version: 1)
    now = Time.current
    published.update_columns(status: "published", effective_at: now, published_at: now)
    assert_raises(ActiveRecord::StatementInvalid) do
      Plans::PlanVersion.transaction(requires_new: true) do
        Plans::PlanVersion.where(id: published.id).delete_all
      end
    end
  end

  test "subscription provider invoice and report references have restrictive foreign keys" do
    version = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "growth" }, version: 1)
    now = Time.current
    version.update_columns(status: "published", effective_at: now, published_at: now)
    invoice = Plans::Public.register_snapshot_reference(
      plan_version_id: version.id,
      reference_type: "InvoiceSnapshot",
      reference_id: SecureRandom.uuid
    )
    report = Plans::Public.register_snapshot_reference(
      plan_version_id: version.id,
      reference_type: "ReportSnapshot",
      reference_id: SecureRandom.uuid
    )

    assert_equal version.id, invoice.plan_version_id
    assert_equal version.id, report.plan_version_id
    foreign_keys = ActiveRecord::Base.connection.foreign_keys(:plan_version_snapshot_references)
    assert foreign_keys.any? { |foreign_key| foreign_key.to_table == "plan_versions" && foreign_key.on_delete == :restrict }
    assert ActiveRecord::Base.connection.foreign_keys(:subscriptions)
      .any? { |foreign_key| foreign_key.to_table == "plan_versions" && foreign_key.on_delete == :restrict }
    assert ActiveRecord::Base.connection.foreign_keys(:billing_plan_provider_mappings)
      .any? { |foreign_key| foreign_key.to_table == "plan_versions" && foreign_key.on_delete == :restrict }
  end
end
