# frozen_string_literal: true

class CreatePlanCatalog < ActiveRecord::Migration[8.1]
  def change
    create_plans
    create_plan_versions
    create_subscription_references
    create_catalog_access_grants
    install_plan_version_guards
  end

  private

  def create_plans
    create_table :plans, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, limit: 32, null: false
      t.integer :display_order, null: false
      t.timestamps
    end
    add_index :plans, :key, unique: true
    add_index :plans, :display_order, unique: true
    add_check_constraint :plans,
      "key IN ('free', 'starter', 'growth', 'agency', 'enterprise')",
      name: "plans_key_allowlist"
    add_check_constraint :plans, "display_order BETWEEN 1 AND 5", name: "plans_display_order_range"
  end

  def create_plan_versions
    create_table :plan_versions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :plan_id, null: false
      t.integer :version, null: false
      t.string :status, limit: 24, null: false, default: "draft"
      t.string :display_name, limit: 80, null: false
      t.string :positioning, limit: 240, null: false
      t.string :currency, limit: 3, null: false, default: "EUR"
      t.string :pricing_kind, limit: 16, null: false
      t.bigint :monthly_price_cents
      t.bigint :annual_price_cents
      t.jsonb :entitlements_snapshot, null: false, default: {}
      t.string :catalog_checksum, limit: 64, null: false
      t.datetime :effective_at
      t.datetime :published_at
      t.datetime :retired_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_foreign_key :plan_versions, :plans, on_delete: :restrict
    add_index :plan_versions, %i[plan_id version], unique: true
    add_index :plan_versions, %i[plan_id status effective_at], name: "index_plan_versions_on_catalog_selection"
    add_index :plan_versions, :catalog_checksum
    add_check_constraint :plan_versions, "version > 0", name: "plan_versions_positive_version"
    add_check_constraint :plan_versions,
      "status IN ('draft', 'published', 'retired', 'grandfathered')",
      name: "plan_versions_status_allowlist"
    add_check_constraint :plan_versions, pricing_shape_sql, name: "plan_versions_pricing_shape"
    add_check_constraint :plan_versions, lifecycle_shape_sql, name: "plan_versions_lifecycle_shape"
    add_check_constraint :plan_versions,
      "catalog_checksum ~ '^[0-9a-f]{64}$'",
      name: "plan_versions_checksum_format"
    add_check_constraint :plan_versions,
      "jsonb_typeof(entitlements_snapshot) = 'object' AND pg_column_size(entitlements_snapshot) <= 32768",
      name: "plan_versions_entitlements_snapshot_bounded"
  end

  def create_subscription_references
    create_table :subscriptions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :plan_version_id, null: false
      t.string :status, limit: 24, null: false, default: "active"
      t.string :billing_interval, limit: 16, null: false
      t.string :plan_key_snapshot, limit: 32, null: false
      t.integer :plan_version_snapshot, null: false
      t.string :plan_display_name_snapshot, limit: 80, null: false
      t.string :currency_snapshot, limit: 3, null: false
      t.string :pricing_kind_snapshot, limit: 16, null: false
      t.bigint :price_cents_snapshot
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.timestamps
    end
    add_foreign_key :subscriptions, :organizations, on_delete: :restrict
    add_foreign_key :subscriptions, :plan_versions, on_delete: :restrict
    add_index :subscriptions, :organization_id, unique: true,
      where: "status = 'active'", name: "index_subscriptions_on_active_organization"
    add_index :subscriptions, %i[plan_version_id status]
    add_check_constraint :subscriptions,
      "status IN ('active', 'inactive')",
      name: "subscriptions_status_allowlist"
    add_check_constraint :subscriptions,
      "billing_interval IN ('monthly', 'annual', 'custom')",
      name: "subscriptions_interval_allowlist"
    add_check_constraint :subscriptions,
      subscription_price_shape_sql,
      name: "subscriptions_snapshot_price_shape"
    add_check_constraint :subscriptions,
      "(status = 'active' AND ended_at IS NULL) OR (status = 'inactive' AND ended_at IS NOT NULL)",
      name: "subscriptions_lifecycle_shape"
  end

  def create_catalog_access_grants
    create_table :plan_catalog_access_grants, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :permission, limit: 32, null: false
      t.datetime :granted_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_foreign_key :plan_catalog_access_grants, :users, on_delete: :restrict
    add_index :plan_catalog_access_grants, %i[user_id permission], unique: true,
      where: "revoked_at IS NULL", name: "index_plan_catalog_grants_on_active_permission"
    add_check_constraint :plan_catalog_access_grants,
      "permission IN ('plan_catalog.read', 'plan_catalog.publish')",
      name: "plan_catalog_grants_permission_allowlist"
    add_check_constraint :plan_catalog_access_grants,
      "revoked_at IS NULL OR revoked_at >= granted_at",
      name: "plan_catalog_grants_revocation_order"
  end

  def pricing_shape_sql
    <<~SQL.squish
      (pricing_kind = 'fixed' AND monthly_price_cents IS NOT NULL AND monthly_price_cents >= 0
        AND annual_price_cents IS NOT NULL AND annual_price_cents >= 0)
      OR (pricing_kind = 'custom' AND monthly_price_cents IS NULL AND annual_price_cents IS NULL)
    SQL
  end

  def lifecycle_shape_sql
    <<~SQL.squish
      (status = 'draft' AND effective_at IS NULL AND published_at IS NULL AND retired_at IS NULL)
      OR (status = 'published' AND effective_at IS NOT NULL AND published_at IS NOT NULL AND retired_at IS NULL)
      OR (status IN ('retired', 'grandfathered') AND effective_at IS NOT NULL
        AND published_at IS NOT NULL AND retired_at IS NOT NULL)
    SQL
  end

  def subscription_price_shape_sql
    <<~SQL.squish
      (pricing_kind_snapshot = 'fixed' AND billing_interval IN ('monthly', 'annual')
        AND price_cents_snapshot IS NOT NULL AND price_cents_snapshot >= 0)
      OR (pricing_kind_snapshot = 'custom' AND billing_interval = 'custom' AND price_cents_snapshot IS NULL)
    SQL
  end

  def install_plan_version_guards
    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE FUNCTION enforce_plan_version_immutability() RETURNS trigger AS $$
          BEGIN
            IF TG_OP = 'DELETE' THEN
              IF OLD.status <> 'draft' THEN
                RAISE EXCEPTION 'non-draft plan versions cannot be deleted' USING ERRCODE = '23514';
              END IF;
              RETURN OLD;
            END IF;

            IF OLD.status <> 'draft' AND (
              NEW.plan_id IS DISTINCT FROM OLD.plan_id OR
              NEW.version IS DISTINCT FROM OLD.version OR
              NEW.display_name IS DISTINCT FROM OLD.display_name OR
              NEW.positioning IS DISTINCT FROM OLD.positioning OR
              NEW.currency IS DISTINCT FROM OLD.currency OR
              NEW.pricing_kind IS DISTINCT FROM OLD.pricing_kind OR
              NEW.monthly_price_cents IS DISTINCT FROM OLD.monthly_price_cents OR
              NEW.annual_price_cents IS DISTINCT FROM OLD.annual_price_cents OR
              NEW.entitlements_snapshot IS DISTINCT FROM OLD.entitlements_snapshot OR
              NEW.catalog_checksum IS DISTINCT FROM OLD.catalog_checksum OR
              NEW.effective_at IS DISTINCT FROM OLD.effective_at OR
              NEW.published_at IS DISTINCT FROM OLD.published_at
            ) THEN
              RAISE EXCEPTION 'non-draft plan version snapshots are immutable' USING ERRCODE = '23514';
            END IF;

            IF (OLD.status = 'published' AND NEW.status NOT IN ('published', 'retired', 'grandfathered')) OR
               (OLD.status IN ('retired', 'grandfathered') AND NEW.status <> OLD.status) THEN
              RAISE EXCEPTION 'invalid plan version lifecycle transition' USING ERRCODE = '23514';
            END IF;
            RETURN NEW;
          END;
          $$ LANGUAGE plpgsql;

          CREATE TRIGGER plan_versions_immutable_snapshot
          BEFORE UPDATE OR DELETE ON plan_versions
          FOR EACH ROW EXECUTE FUNCTION enforce_plan_version_immutability();
        SQL
      end
      direction.down do
        execute "DROP TRIGGER IF EXISTS plan_versions_immutable_snapshot ON plan_versions"
        execute "DROP FUNCTION IF EXISTS enforce_plan_version_immutability()"
      end
    end
  end
end
