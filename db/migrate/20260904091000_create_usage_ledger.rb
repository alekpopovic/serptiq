# frozen_string_literal: true

class CreateUsageLedger < ActiveRecord::Migration[8.1]
  def up
    create_meter_definitions
    create_meter_rates
    create_usage_windows
    create_usage_events
    install_guards
  end

  def down
    execute "DROP TRIGGER IF EXISTS usage_events_immutable_and_consistent ON usage_events"
    execute "DROP FUNCTION IF EXISTS enforce_usage_event_integrity()"
    execute "DROP TRIGGER IF EXISTS usage_windows_non_overlapping ON usage_windows"
    execute "DROP FUNCTION IF EXISTS enforce_usage_window_integrity()"
    execute "DROP TRIGGER IF EXISTS usage_meter_rates_immutable ON usage_meter_rates"
    execute "DROP TRIGGER IF EXISTS usage_meter_definitions_immutable ON usage_meter_definitions"
    execute "DROP FUNCTION IF EXISTS enforce_usage_catalog_immutability()"
    drop_table :usage_events
    drop_table :usage_windows
    drop_table :usage_meter_rates
    drop_table :usage_meter_definitions
  end

  private

  def create_meter_definitions
    create_table :usage_meter_definitions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, limit: 96, null: false
      t.string :name, limit: 100, null: false
      t.string :unit, limit: 32, null: false
      t.string :billing_unit, limit: 32, null: false
      t.string :pool_key, limit: 96, null: false
      t.string :quota_entitlement_key, limit: 96
      t.string :window_policy, limit: 32, null: false
      t.string :description, limit: 240, null: false
      t.string :catalog_checksum, limit: 64, null: false
      t.timestamps
    end
    add_index :usage_meter_definitions, :key, unique: true
    add_index :usage_meter_definitions, %i[id key], unique: true,
      name: "index_usage_meter_definitions_on_id_and_key"
    add_check_constraint :usage_meter_definitions,
      "key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$' AND " \
        "pool_key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'",
      name: "usage_meter_definitions_key_format"
    add_check_constraint :usage_meter_definitions,
      "quota_entitlement_key IS NULL OR " \
        "quota_entitlement_key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'",
      name: "usage_meter_definitions_entitlement_format"
    add_check_constraint :usage_meter_definitions,
      "unit ~ '^[a-z][a-z0-9_]{1,31}$' AND billing_unit ~ '^[a-z][a-z0-9_]{1,31}$'",
      name: "usage_meter_definitions_unit_format"
    add_check_constraint :usage_meter_definitions,
      "window_policy IN ('utc_calendar_month', 'provider_billing_period')",
      name: "usage_meter_definitions_window_policy_allowlist"
    add_check_constraint :usage_meter_definitions,
      "char_length(name) BETWEEN 3 AND 100 AND name = btrim(name) AND " \
        "char_length(description) BETWEEN 3 AND 240 AND description = btrim(description)",
      name: "usage_meter_definitions_text_format"
    add_check_constraint :usage_meter_definitions,
      "catalog_checksum ~ '^[0-9a-f]{64}$'", name: "usage_meter_definitions_checksum_format"
  end

  def create_meter_rates
    create_table :usage_meter_rates, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :usage_meter_definition_id, null: false
      t.integer :version, null: false
      t.decimal :weight, precision: 18, scale: 6, null: false
      t.datetime :effective_at, null: false
      t.string :catalog_checksum, limit: 64, null: false
      t.timestamps
    end
    add_foreign_key :usage_meter_rates, :usage_meter_definitions, on_delete: :restrict
    add_index :usage_meter_rates, %i[usage_meter_definition_id version], unique: true,
      name: "index_usage_meter_rates_on_definition_and_version"
    add_index :usage_meter_rates, %i[usage_meter_definition_id effective_at], unique: true,
      name: "index_usage_meter_rates_on_definition_and_effective_at"
    add_index :usage_meter_rates, %i[usage_meter_definition_id id], unique: true,
      name: "index_usage_meter_rates_on_definition_and_id"
    add_check_constraint :usage_meter_rates, "version > 0", name: "usage_meter_rates_positive_version"
    add_check_constraint :usage_meter_rates, "weight > 0", name: "usage_meter_rates_positive_weight"
    add_check_constraint :usage_meter_rates,
      "catalog_checksum ~ '^[0-9a-f]{64}$'", name: "usage_meter_rates_checksum_format"
  end

  def create_usage_windows
    create_table :usage_windows, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :usage_meter_definition_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :window_policy, limit: 32, null: false
      t.string :time_zone_name, limit: 64, null: false
      t.string :period_reference_digest, limit: 64
      t.uuid :subscription_id
      t.uuid :plan_version_id
      t.bigint :subscription_revision
      t.datetime :created_at, null: false
    end
    add_foreign_key :usage_windows, :organizations, on_delete: :restrict
    add_foreign_key :usage_windows, :usage_meter_definitions, on_delete: :restrict
    add_foreign_key :usage_windows, :subscriptions,
      column: %i[organization_id subscription_id plan_version_id],
      primary_key: %i[organization_id id plan_version_id], on_delete: :restrict,
      name: "fk_usage_windows_subscription_snapshot"
    add_index :usage_windows,
      %i[organization_id usage_meter_definition_id starts_at ends_at], unique: true,
      name: "index_usage_windows_on_tenant_meter_period"
    add_index :usage_windows, %i[organization_id starts_at ends_at],
      name: "index_usage_windows_on_tenant_period"
    add_index :usage_windows, %i[organization_id id usage_meter_definition_id], unique: true,
      name: "index_usage_windows_on_tenant_identity"
    add_index :usage_windows, %i[subscription_id starts_at],
      name: "index_usage_windows_on_subscription_period"
    add_index :usage_windows,
      %i[organization_id usage_meter_definition_id period_reference_digest], unique: true,
      where: "period_reference_digest IS NOT NULL", name: "index_usage_windows_on_provider_period"
    add_check_constraint :usage_windows, "ends_at > starts_at", name: "usage_windows_positive_period"
    add_check_constraint :usage_windows,
      "window_policy IN ('utc_calendar_month', 'provider_billing_period')",
      name: "usage_windows_policy_allowlist"
    add_check_constraint :usage_windows,
      "char_length(time_zone_name) BETWEEN 1 AND 64 AND time_zone_name = btrim(time_zone_name)",
      name: "usage_windows_time_zone_format"
    add_check_constraint :usage_windows, <<~SQL.squish, name: "usage_windows_period_reference_shape"
      (window_policy = 'utc_calendar_month' AND time_zone_name = 'UTC' AND period_reference_digest IS NULL)
      OR (window_policy = 'provider_billing_period'
        AND period_reference_digest ~ '^[0-9a-f]{64}$')
    SQL
    add_check_constraint :usage_windows, <<~SQL.squish, name: "usage_windows_subscription_context_shape"
      (subscription_id IS NULL AND plan_version_id IS NULL AND subscription_revision IS NULL)
      OR (subscription_id IS NOT NULL AND plan_version_id IS NOT NULL AND subscription_revision >= 0)
    SQL
  end

  def create_usage_events
    create_table :usage_events, id: :bigint do |t|
      t.uuid :organization_id, null: false
      t.uuid :source_organization_id, null: false
      t.uuid :usage_window_id, null: false
      t.uuid :usage_meter_definition_id, null: false
      t.uuid :usage_meter_rate_id, null: false
      t.string :idempotency_key_digest, limit: 64, null: false
      t.string :request_checksum, limit: 64, null: false
      t.string :event_kind, limit: 24, null: false
      t.decimal :quantity, precision: 24, scale: 6, null: false
      t.decimal :applied_weight, precision: 18, scale: 6, null: false
      t.decimal :billed_quantity, precision: 30, scale: 6, null: false
      t.string :source_type, limit: 48, null: false
      t.uuid :source_id, null: false
      t.bigint :correction_of_event_id
      t.uuid :actor_membership_id
      t.string :reason_code, limit: 64
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.datetime :recorded_at, null: false
    end
    add_foreign_key :usage_events, :organizations, on_delete: :restrict
    add_foreign_key :usage_events, :organizations, column: :source_organization_id, on_delete: :restrict,
      name: "fk_usage_events_source_organization"
    add_foreign_key :usage_events, :usage_windows,
      column: %i[organization_id usage_window_id usage_meter_definition_id],
      primary_key: %i[organization_id id usage_meter_definition_id], on_delete: :restrict,
      name: "fk_usage_events_tenant_window_meter"
    add_foreign_key :usage_events, :usage_meter_rates,
      column: %i[usage_meter_definition_id usage_meter_rate_id],
      primary_key: %i[usage_meter_definition_id id], on_delete: :restrict,
      name: "fk_usage_events_meter_rate"
    add_foreign_key :usage_events, :memberships,
      column: %i[organization_id actor_membership_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_usage_events_same_org_actor"
    add_index :usage_events, %i[organization_id idempotency_key_digest], unique: true,
      name: "index_usage_events_on_tenant_idempotency"
    add_index :usage_events, %i[organization_id usage_window_id recorded_at id],
      name: "index_usage_events_on_tenant_window_recorded"
    add_index :usage_events, %i[organization_id source_type source_id occurred_at],
      name: "index_usage_events_on_tenant_source"
    add_index :usage_events, %i[usage_meter_definition_id occurred_at],
      name: "index_usage_events_on_meter_occurred"
    add_index :usage_events, %i[organization_id id usage_window_id usage_meter_definition_id], unique: true,
      name: "index_usage_events_on_correction_identity"
    add_foreign_key :usage_events, :usage_events,
      column: %i[organization_id correction_of_event_id usage_window_id usage_meter_definition_id],
      primary_key: %i[organization_id id usage_window_id usage_meter_definition_id],
      on_delete: :restrict, name: "fk_usage_events_same_context_correction"
    add_check_constraint :usage_events,
      "organization_id = source_organization_id", name: "usage_events_source_tenant_match"
    add_check_constraint :usage_events,
      "idempotency_key_digest ~ '^[0-9a-f]{64}$' AND request_checksum ~ '^[0-9a-f]{64}$'",
      name: "usage_events_digest_format"
    add_check_constraint :usage_events,
      "event_kind IN ('usage', 'correction', 'manual_adjustment')",
      name: "usage_events_kind_allowlist"
    add_check_constraint :usage_events, <<~SQL.squish, name: "usage_events_kind_shape"
      (event_kind = 'usage' AND quantity > 0 AND correction_of_event_id IS NULL
        AND actor_membership_id IS NULL AND reason_code IS NULL)
      OR (event_kind = 'correction' AND quantity <> 0 AND correction_of_event_id IS NOT NULL
        AND reason_code IS NOT NULL)
      OR (event_kind = 'manual_adjustment' AND quantity <> 0 AND correction_of_event_id IS NULL
        AND actor_membership_id IS NOT NULL AND reason_code IS NOT NULL)
    SQL
    add_check_constraint :usage_events,
      "applied_weight > 0 AND billed_quantity = quantity * applied_weight",
      name: "usage_events_weighted_quantity"
    add_check_constraint :usage_events,
      "source_type ~ '^[A-Z][A-Za-z0-9]{0,47}$'",
      name: "usage_events_source_type_format"
    add_check_constraint :usage_events,
      "reason_code IS NULL OR reason_code ~ '^[a-z][a-z0-9_]{1,63}$'",
      name: "usage_events_reason_code_format"
    add_check_constraint :usage_events,
      "jsonb_typeof(metadata) = 'object' AND pg_column_size(metadata) <= 4096",
      name: "usage_events_metadata_bounded"
    add_check_constraint :usage_events,
      "recorded_at >= occurred_at", name: "usage_events_recording_order"
  end

  def install_guards
    execute <<~SQL
      CREATE FUNCTION enforce_usage_catalog_immutability() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'usage catalog rows are immutable' USING ERRCODE = '23514';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER usage_meter_definitions_immutable
      BEFORE UPDATE OR DELETE ON usage_meter_definitions
      FOR EACH ROW EXECUTE FUNCTION enforce_usage_catalog_immutability();

      CREATE TRIGGER usage_meter_rates_immutable
      BEFORE UPDATE OR DELETE ON usage_meter_rates
      FOR EACH ROW EXECUTE FUNCTION enforce_usage_catalog_immutability();

      CREATE FUNCTION enforce_usage_window_integrity() RETURNS trigger AS $$
      BEGIN
        IF TG_OP <> 'INSERT' THEN
          RAISE EXCEPTION 'usage windows are immutable' USING ERRCODE = '23514';
        END IF;
        PERFORM pg_advisory_xact_lock(hashtextextended(NEW.organization_id::text || ':' ||
          NEW.usage_meter_definition_id::text, 0));
        IF EXISTS (
          SELECT 1 FROM usage_windows existing
          WHERE existing.organization_id = NEW.organization_id
            AND existing.usage_meter_definition_id = NEW.usage_meter_definition_id
            AND tstzrange(existing.starts_at, existing.ends_at, '[)') &&
              tstzrange(NEW.starts_at, NEW.ends_at, '[)')
            AND (existing.starts_at, existing.ends_at) <> (NEW.starts_at, NEW.ends_at)
        ) THEN
          RAISE EXCEPTION 'usage windows cannot overlap' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER usage_windows_non_overlapping
      BEFORE INSERT OR UPDATE OR DELETE ON usage_windows
      FOR EACH ROW EXECUTE FUNCTION enforce_usage_window_integrity();

      CREATE FUNCTION enforce_usage_event_integrity() RETURNS trigger AS $$
      DECLARE
        original usage_events%ROWTYPE;
        corrected numeric;
        event_window usage_windows%ROWTYPE;
      BEGIN
        IF TG_OP <> 'INSERT' THEN
          RAISE EXCEPTION 'usage events are append-only' USING ERRCODE = '23514';
        END IF;

        SELECT * INTO event_window FROM usage_windows WHERE id = NEW.usage_window_id;
        IF NEW.event_kind = 'usage' AND
          (NEW.occurred_at < event_window.starts_at OR NEW.occurred_at >= event_window.ends_at) THEN
          RAISE EXCEPTION 'usage event occurred outside its window' USING ERRCODE = '23514';
        END IF;

        IF NEW.event_kind = 'correction' THEN
          PERFORM pg_advisory_xact_lock(NEW.correction_of_event_id);
          SELECT * INTO original FROM usage_events WHERE id = NEW.correction_of_event_id;
          IF original.id IS NULL OR original.event_kind = 'correction' OR
            original.usage_meter_rate_id <> NEW.usage_meter_rate_id OR
            original.applied_weight <> NEW.applied_weight OR
            original.source_type <> NEW.source_type OR original.source_id <> NEW.source_id THEN
            RAISE EXCEPTION 'usage correction target is invalid' USING ERRCODE = '23514';
          END IF;
          SELECT original.quantity + COALESCE(sum(quantity), 0) INTO corrected
          FROM usage_events WHERE correction_of_event_id = original.id;
          corrected := corrected + NEW.quantity;
          IF (original.quantity > 0 AND (NEW.quantity >= 0 OR corrected < 0)) OR
            (original.quantity < 0 AND (NEW.quantity <= 0 OR corrected > 0)) THEN
            RAISE EXCEPTION 'usage correction overcompensates its target' USING ERRCODE = '23514';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER usage_events_immutable_and_consistent
      BEFORE INSERT OR UPDATE OR DELETE ON usage_events
      FOR EACH ROW EXECUTE FUNCTION enforce_usage_event_integrity();
    SQL
  end
end
