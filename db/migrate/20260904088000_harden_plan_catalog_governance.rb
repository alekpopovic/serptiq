# frozen_string_literal: true

class HardenPlanCatalogGovernance < ActiveRecord::Migration[8.1]
  def up
    create_snapshot_references
    create_provider_mappings
    install_plan_guards
    install_version_guards
  end

  def down
    restore_version_guards
    execute "DROP TRIGGER IF EXISTS plans_prevent_deletion ON plans"
    execute "DROP FUNCTION IF EXISTS prevent_plan_deletion()"
    drop_table :billing_plan_provider_mappings, if_exists: true
    drop_table :plan_version_snapshot_references, if_exists: true
  end

  private

  def create_snapshot_references
    create_table :plan_version_snapshot_references, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :plan_version_id, null: false
      t.string :reference_type, limit: 32, null: false
      t.uuid :reference_id, null: false
      t.datetime :created_at, null: false
    end
    add_foreign_key :plan_version_snapshot_references, :plan_versions, on_delete: :restrict
    add_index :plan_version_snapshot_references,
      %i[reference_type reference_id plan_version_id],
      unique: true,
      name: "index_plan_version_snapshot_references_on_identity"
    add_check_constraint :plan_version_snapshot_references,
      "reference_type IN ('InvoiceSnapshot', 'ReportSnapshot')",
      name: "plan_version_snapshot_references_type_allowlist"
  end

  def create_provider_mappings
    create_table :billing_plan_provider_mappings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :plan_version_id, null: false
      t.string :provider, limit: 32, null: false
      t.string :environment, limit: 16, null: false
      t.string :currency, limit: 3, null: false
      t.string :billing_interval, limit: 16, null: false
      t.string :provider_variant_id, limit: 128, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_foreign_key :billing_plan_provider_mappings, :plan_versions, on_delete: :restrict
    add_index :billing_plan_provider_mappings,
      %i[plan_version_id provider environment currency billing_interval],
      unique: true,
      where: "active = true",
      name: "index_billing_plan_mappings_on_active_target"
    add_index :billing_plan_provider_mappings,
      %i[provider environment provider_variant_id],
      unique: true,
      name: "index_billing_plan_mappings_on_provider_variant"
    add_check_constraint :billing_plan_provider_mappings,
      "provider ~ '^[a-z][a-z0-9_]{1,31}$'",
      name: "billing_plan_mappings_provider_format"
    add_check_constraint :billing_plan_provider_mappings,
      "environment IN ('development', 'test', 'staging', 'production')",
      name: "billing_plan_mappings_environment_allowlist"
    add_check_constraint :billing_plan_provider_mappings,
      "currency ~ '^[A-Z]{3}$'",
      name: "billing_plan_mappings_currency_format"
    add_check_constraint :billing_plan_provider_mappings,
      "billing_interval IN ('monthly', 'annual')",
      name: "billing_plan_mappings_interval_allowlist"
    add_check_constraint :billing_plan_provider_mappings,
      "provider_variant_id ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$'",
      name: "billing_plan_mappings_variant_format"
  end

  def install_plan_guards
    execute <<~SQL
      CREATE FUNCTION prevent_plan_deletion() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'stable commercial plans cannot be deleted' USING ERRCODE = '23514';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER plans_prevent_deletion
      BEFORE DELETE ON plans
      FOR EACH ROW EXECUTE FUNCTION prevent_plan_deletion();
    SQL
  end

  def install_version_guards
    execute version_guard_sql(allow_grandfather_retirement: true, protect_audit_targets: true)
  end

  def restore_version_guards
    execute version_guard_sql(allow_grandfather_retirement: false, protect_audit_targets: false)
  end

  def version_guard_sql(allow_grandfather_retirement:, protect_audit_targets:)
    grandfather_condition = if allow_grandfather_retirement
      "(OLD.status = 'grandfathered' AND NEW.status NOT IN ('grandfathered', 'retired'))"
    else
      "(OLD.status = 'grandfathered' AND NEW.status <> OLD.status)"
    end
    audit_guard = if protect_audit_targets
      <<~SQL.squish
        IF EXISTS (
          SELECT 1 FROM audit_events
          WHERE target_type = 'PlanVersion' AND target_id = OLD.id
        ) THEN
          RAISE EXCEPTION 'audited plan versions cannot be deleted' USING ERRCODE = '23514';
        END IF;
      SQL
    end

    <<~SQL
      CREATE OR REPLACE FUNCTION enforce_plan_version_immutability() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          #{audit_guard}
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
           #{grandfather_condition} OR
           (OLD.status = 'retired' AND NEW.status <> OLD.status) THEN
          RAISE EXCEPTION 'invalid plan version lifecycle transition' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end
end
