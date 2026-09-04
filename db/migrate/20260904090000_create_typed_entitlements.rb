# frozen_string_literal: true

class CreateTypedEntitlements < ActiveRecord::Migration[8.1]
  def up
    create_definitions
    create_plan_values
    create_subscription_contexts
    create_overrides
    install_integrity_triggers
    backfill_subscription_contexts
  end

  def down
    execute "DROP TRIGGER IF EXISTS organization_entitlement_overrides_append_only ON organization_entitlement_overrides"
    execute "DROP FUNCTION IF EXISTS enforce_organization_entitlement_override_append_only()"
    execute "DROP TRIGGER IF EXISTS plan_entitlements_immutable_snapshot ON plan_entitlements"
    execute "DROP FUNCTION IF EXISTS enforce_plan_entitlement_immutability()"
    execute "DROP TRIGGER IF EXISTS entitlement_definitions_stable ON entitlement_definitions"
    execute "DROP FUNCTION IF EXISTS enforce_entitlement_definition_stability()"
    drop_table :organization_entitlement_overrides
    drop_table :entitlement_subscription_contexts
    drop_table :plan_entitlements
    drop_table :entitlement_definitions
    remove_index :subscriptions, name: "index_subscriptions_on_org_id_plan_version"
    remove_column :subscriptions, :lock_version
  end

  private

  def create_definitions
    create_table :entitlement_definitions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, limit: 96, null: false
      t.string :value_type, limit: 16, null: false
      t.string :unit, limit: 32, null: false
      t.string :category, limit: 32, null: false
      t.decimal :minimum_value, precision: 24, scale: 6
      t.decimal :maximum_value, precision: 24, scale: 6
      t.jsonb :allowed_values, null: false, default: []
      t.integer :max_length
      t.boolean :allow_custom, null: false, default: false
      t.boolean :security_sensitive, null: false, default: false
      t.jsonb :system_default, null: false
      t.string :customer_description, limit: 240, null: false
      t.string :catalog_checksum, limit: 64, null: false
      t.timestamps
    end
    add_index :entitlement_definitions, :key, unique: true
    add_index :entitlement_definitions, %i[id value_type], unique: true,
      name: "index_entitlement_definitions_on_id_and_type"
    add_check_constraint :entitlement_definitions,
      "key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'",
      name: "entitlement_definitions_key_format"
    add_check_constraint :entitlement_definitions,
      "value_type IN ('boolean', 'integer', 'decimal', 'enum', 'string')",
      name: "entitlement_definitions_type_allowlist"
    add_check_constraint :entitlement_definitions,
      "unit ~ '^[a-z][a-z0-9_]{1,31}$' AND category ~ '^[a-z][a-z0-9_]{1,31}$'",
      name: "entitlement_definitions_taxonomy_format"
    add_check_constraint :entitlement_definitions,
      "minimum_value IS NULL OR maximum_value IS NULL OR minimum_value <= maximum_value",
      name: "entitlement_definitions_bounds_order"
    add_check_constraint :entitlement_definitions,
      "jsonb_typeof(allowed_values) = 'array' AND pg_column_size(allowed_values) <= 4096",
      name: "entitlement_definitions_allowed_values_shape"
    add_check_constraint :entitlement_definitions,
      "max_length IS NULL OR max_length BETWEEN 1 AND 4096",
      name: "entitlement_definitions_max_length_range"
    add_check_constraint :entitlement_definitions,
      "char_length(customer_description) BETWEEN 3 AND 240 AND customer_description = btrim(customer_description)",
      name: "entitlement_definitions_description_format"
    add_check_constraint :entitlement_definitions,
      "catalog_checksum ~ '^[0-9a-f]{64}$'",
      name: "entitlement_definitions_checksum_format"
    add_check_constraint :entitlement_definitions,
      definition_validation_shape_sql,
      name: "entitlement_definitions_validation_shape"
    add_check_constraint :entitlement_definitions,
      typed_json_cases("system_default"),
      name: "entitlement_definitions_default_type"
    add_check_constraint :entitlement_definitions,
      security_default_sql,
      name: "entitlement_definitions_security_default"
  end

  def create_plan_values
    create_table :plan_entitlements, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :plan_version_id, null: false
      t.uuid :entitlement_definition_id, null: false
      t.string :value_type, limit: 16, null: false
      t.string :value_state, limit: 16, null: false
      t.jsonb :value
      t.string :catalog_checksum, limit: 64, null: false
      t.timestamps
    end
    add_foreign_key :plan_entitlements, :plan_versions, on_delete: :restrict
    add_foreign_key :plan_entitlements, :entitlement_definitions,
      column: %i[entitlement_definition_id value_type], primary_key: %i[id value_type],
      on_delete: :restrict, name: "fk_plan_entitlements_definition_type"
    add_index :plan_entitlements, %i[plan_version_id entitlement_definition_id], unique: true,
      name: "index_plan_entitlements_on_version_and_definition"
    add_check_constraint :plan_entitlements, typed_value_shape_sql,
      name: "plan_entitlements_typed_value_shape"
    add_check_constraint :plan_entitlements,
      "catalog_checksum ~ '^[0-9a-f]{64}$'",
      name: "plan_entitlements_checksum_format"
  end

  def create_subscription_contexts
    add_column :subscriptions, :lock_version, :integer, null: false, default: 0
    add_index :subscriptions, %i[organization_id id plan_version_id], unique: true,
      name: "index_subscriptions_on_org_id_plan_version"
    create_table :entitlement_subscription_contexts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :subscription_id, null: false
      t.uuid :plan_version_id, null: false
      t.bigint :subscription_revision, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_foreign_key :entitlement_subscription_contexts, :organizations, on_delete: :restrict
    add_foreign_key :entitlement_subscription_contexts, :subscriptions,
      column: %i[organization_id subscription_id plan_version_id],
      primary_key: %i[organization_id id plan_version_id], on_delete: :restrict,
      name: "fk_entitlement_contexts_subscription_identity"
    add_foreign_key :entitlement_subscription_contexts, :plan_versions, on_delete: :restrict
    add_index :entitlement_subscription_contexts, :subscription_id, unique: true
    add_index :entitlement_subscription_contexts, :organization_id, unique: true,
      where: "active = true", name: "index_entitlement_contexts_on_active_organization"
    add_check_constraint :entitlement_subscription_contexts,
      "subscription_revision >= 0", name: "entitlement_contexts_nonnegative_revision"
  end

  def create_overrides
    create_table :organization_entitlement_overrides, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :entitlement_definition_id, null: false
      t.string :value_type, limit: 16, null: false
      t.jsonb :value, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :reason, limit: 500, null: false
      t.string :source, limit: 24, null: false
      t.uuid :created_by_membership_id, null: false
      t.datetime :revoked_at
      t.uuid :revoked_by_membership_id
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_foreign_key :organization_entitlement_overrides, :organizations, on_delete: :restrict
    add_foreign_key :organization_entitlement_overrides, :entitlement_definitions,
      column: %i[entitlement_definition_id value_type], primary_key: %i[id value_type],
      on_delete: :restrict, name: "fk_entitlement_overrides_definition_type"
    add_foreign_key :organization_entitlement_overrides, :memberships,
      column: %i[organization_id created_by_membership_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_entitlement_overrides_same_org_creator"
    add_foreign_key :organization_entitlement_overrides, :memberships,
      column: %i[organization_id revoked_by_membership_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_entitlement_overrides_same_org_revoker"
    add_index :organization_entitlement_overrides, %i[organization_id entitlement_definition_id],
      unique: true, where: "revoked_at IS NULL", name: "index_entitlement_overrides_on_active_definition"
    add_index :organization_entitlement_overrides,
      %i[organization_id starts_at ends_at], name: "index_entitlement_overrides_on_validity"
    add_check_constraint :organization_entitlement_overrides,
      configured_value_shape_sql, name: "entitlement_overrides_typed_value_shape"
    add_check_constraint :organization_entitlement_overrides,
      "ends_at IS NULL OR ends_at > starts_at", name: "entitlement_overrides_validity_order"
    add_check_constraint :organization_entitlement_overrides,
      "source IN ('contract', 'support', 'emergency')", name: "entitlement_overrides_source_allowlist"
    add_check_constraint :organization_entitlement_overrides,
      "char_length(reason) BETWEEN 3 AND 500 AND reason = btrim(reason)",
      name: "entitlement_overrides_reason_format"
    add_check_constraint :organization_entitlement_overrides,
      "(revoked_at IS NULL AND revoked_by_membership_id IS NULL) OR " \
        "(revoked_at IS NOT NULL AND revoked_by_membership_id IS NOT NULL AND revoked_at >= created_at)",
      name: "entitlement_overrides_revocation_shape"
  end

  def install_integrity_triggers
    execute <<~SQL
      CREATE FUNCTION enforce_entitlement_definition_stability() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' OR NEW IS DISTINCT FROM OLD THEN
          RAISE EXCEPTION 'entitlement definition identity is immutable' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER entitlement_definitions_stable
      BEFORE DELETE OR UPDATE ON entitlement_definitions
      FOR EACH ROW EXECUTE FUNCTION enforce_entitlement_definition_stability();

      CREATE FUNCTION enforce_plan_entitlement_immutability() RETURNS trigger AS $$
      BEGIN
        IF EXISTS (SELECT 1 FROM plan_versions WHERE id = OLD.plan_version_id AND status <> 'draft') THEN
          RAISE EXCEPTION 'published plan entitlements are immutable' USING ERRCODE = '23514';
        END IF;
        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER plan_entitlements_immutable_snapshot
      BEFORE DELETE OR UPDATE ON plan_entitlements
      FOR EACH ROW EXECUTE FUNCTION enforce_plan_entitlement_immutability();

      CREATE FUNCTION enforce_organization_entitlement_override_append_only() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'entitlement overrides are append-only' USING ERRCODE = '23514';
        END IF;
        IF OLD.organization_id IS DISTINCT FROM NEW.organization_id OR
           OLD.entitlement_definition_id IS DISTINCT FROM NEW.entitlement_definition_id OR
           OLD.value_type IS DISTINCT FROM NEW.value_type OR OLD.value IS DISTINCT FROM NEW.value OR
           OLD.starts_at IS DISTINCT FROM NEW.starts_at OR OLD.ends_at IS DISTINCT FROM NEW.ends_at OR
           OLD.reason IS DISTINCT FROM NEW.reason OR OLD.source IS DISTINCT FROM NEW.source OR
           OLD.created_by_membership_id IS DISTINCT FROM NEW.created_by_membership_id OR
           OLD.revoked_at IS NOT NULL OR NEW.revoked_at IS NULL OR NEW.revoked_by_membership_id IS NULL THEN
          RAISE EXCEPTION 'entitlement override history is immutable' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER organization_entitlement_overrides_append_only
      BEFORE DELETE OR UPDATE ON organization_entitlement_overrides
      FOR EACH ROW EXECUTE FUNCTION enforce_organization_entitlement_override_append_only();
    SQL
  end

  def backfill_subscription_contexts
    execute <<~SQL.squish
      INSERT INTO entitlement_subscription_contexts
        (id, organization_id, subscription_id, plan_version_id, subscription_revision, active, created_at, updated_at)
      SELECT gen_random_uuid(), organization_id, id, plan_version_id, lock_version, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM subscriptions
      WHERE status = 'active'
    SQL
  end

  def typed_value_shape_sql
    <<~SQL.squish
      (value_state = 'custom' AND value IS NULL)
      OR (value_state = 'configured' AND #{typed_json_cases("value")})
    SQL
  end

  def configured_value_shape_sql
    typed_json_cases("value")
  end

  def typed_json_cases(column)
    <<~SQL.squish
      ((value_type = 'boolean' AND jsonb_typeof(#{column}) = 'boolean')
      OR (value_type = 'integer' AND jsonb_typeof(#{column}) = 'number'
        AND (#{column} #>> '{}') ~ '^-?(0|[1-9][0-9]*)$')
      OR (value_type = 'decimal' AND jsonb_typeof(#{column}) = 'string'
        AND (#{column} #>> '{}') ~ '^-?(0|[1-9][0-9]*)(\\.[0-9]+)?$')
      OR (value_type IN ('enum', 'string') AND jsonb_typeof(#{column}) = 'string'))
    SQL
  end

  def definition_validation_shape_sql
    <<~SQL.squish
      (value_type = 'boolean' AND minimum_value IS NULL AND maximum_value IS NULL
        AND allowed_values = '[]'::jsonb AND max_length IS NULL AND allow_custom = false)
      OR (value_type IN ('integer', 'decimal') AND minimum_value IS NOT NULL AND maximum_value IS NOT NULL
        AND minimum_value <= maximum_value AND allowed_values = '[]'::jsonb AND max_length IS NULL)
      OR (value_type = 'enum' AND minimum_value IS NULL AND maximum_value IS NULL
        AND jsonb_array_length(allowed_values) > 0 AND max_length IS NULL)
      OR (value_type = 'string' AND minimum_value IS NULL AND maximum_value IS NULL
        AND allowed_values = '[]'::jsonb AND max_length BETWEEN 1 AND 4096)
    SQL
  end

  def security_default_sql
    <<~SQL.squish
      security_sensitive = false
      OR (value_type = 'boolean' AND system_default = 'false'::jsonb)
      OR (value_type = 'integer' AND system_default = '0'::jsonb)
      OR (value_type = 'decimal' AND (system_default #>> '{}') = '0')
      OR (value_type IN ('enum', 'string') AND (system_default #>> '{}') IN ('none', 'disabled'))
    SQL
  end
end
