# frozen_string_literal: true

require "test_helper"

class EntitlementsCatalogSyncTest < ActiveSupport::TestCase
  setup { Plans::Public.sync_catalog }

  test "sync creates 47 stable definitions and all 235 plan-version values idempotently" do
    first = Entitlements::Public.sync_catalog
    ids = Entitlements::Definition.order(:key).pluck(:key, :id)
    second = Entitlements::Public.sync_catalog

    assert_equal 282, first.change_count
    assert_equal 47, first.definition_count
    assert_equal 235, first.plan_value_count
    assert_equal 0, second.change_count
    assert_equal ids, Entitlements::Definition.order(:key).pluck(:key, :id)
    assert_equal 47, Entitlements::Definition.count
    assert_equal 235, Entitlements::PlanValue.count
    assert Entitlements::PlanValue.where(value_state: "custom", value: nil).exists?
    assert_equal 1, Auditing::AuditEvent.where(action: "entitlement.catalog_synchronized").count
  end

  test "dry run reports changes without database or audit writes" do
    result = Entitlements::Public.sync_catalog(dry_run: true)

    assert_predicate result, :dry_run?
    assert_equal 282, result.change_count
    assert_equal 0, Entitlements::Definition.count
    assert_equal 0, Entitlements::PlanValue.count
    refute Auditing::AuditEvent.exists?(action: "entitlement.catalog_synchronized")
  end

  test "database and model protect definition identity and published plan values" do
    Entitlements::Public.sync_catalog
    definition = Entitlements::Definition.find_by!(key: "reports.pdf")
    value = Entitlements::PlanValue.joins(:definition).find_by!(
      plan_version_id: plan_version("starter").id,
      entitlement_definitions: { key: "reports.pdf" }
    )
    assert_raises(ActiveRecord::StatementInvalid) do
      Entitlements::PlanValue.transaction(requires_new: true) do
        Entitlements::PlanValue.where(id: value.id).update_all(value: "true")
      end
    end
    publish(plan_version("starter"))

    assert_raises(ActiveRecord::ReadOnlyRecord) { definition.update!(unit: "other") }
    assert_raises(ActiveRecord::StatementInvalid) do
      Entitlements::Definition.transaction(requires_new: true) do
        Entitlements::Definition.where(id: definition.id).update_all(value_type: "string")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Entitlements::PlanValue.transaction(requires_new: true) do
        Entitlements::PlanValue.where(id: value.id).update_all(value: false)
      end
    end
  end

  test "database requires fail-closed defaults for security-sensitive definitions" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Entitlements::Definition.transaction(requires_new: true) do
        Entitlements::Definition.insert_all!([ {
          key: "test.unsafe",
          value_type: "boolean",
          unit: "capability",
          category: "testing",
          allowed_values: [],
          allow_custom: false,
          security_sensitive: true,
          system_default: true,
          customer_description: "Unsafe test default",
          catalog_checksum: "a" * 64,
          created_at: Time.current,
          updated_at: Time.current
        } ])
      end
    end
  end

  private

  def plan_version(key)
    Plans::PlanVersion.joins(:plan).find_by!(plans: { key: key }, version: 1)
  end

  def publish(version)
    now = Time.current
    version.update_columns(status: "published", effective_at: now, published_at: now)
  end
end
