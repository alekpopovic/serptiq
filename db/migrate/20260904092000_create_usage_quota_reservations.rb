# frozen_string_literal: true

class CreateUsageQuotaReservations < ActiveRecord::Migration[8.1]
  def up
    create_reservations
    create_operations
    install_pool_lock
    install_reservation_guards
    add_usage_event_pool_lock
  end

  def down
    restore_usage_event_guard
    execute "DROP TRIGGER IF EXISTS usage_quota_reservation_operations_immutable ON usage_quota_reservation_operations"
    execute "DROP FUNCTION IF EXISTS enforce_usage_quota_reservation_operation_immutability()"
    execute "DROP TRIGGER IF EXISTS usage_quota_reservations_lifecycle ON usage_quota_reservations"
    execute "DROP FUNCTION IF EXISTS enforce_usage_quota_reservation_lifecycle()"
    drop_table :usage_quota_reservation_operations
    drop_table :usage_quota_reservations
    execute "DROP FUNCTION IF EXISTS lock_usage_quota_pool(uuid)"
  end

  private

  def create_reservations
    create_table :usage_quota_reservations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :source_organization_id, null: false
      t.uuid :usage_window_id, null: false
      t.uuid :usage_meter_definition_id, null: false
      t.uuid :usage_meter_rate_id, null: false
      t.string :idempotency_key_digest, limit: 64, null: false
      t.string :request_checksum, limit: 64, null: false
      t.string :state, limit: 16, null: false
      t.decimal :requested_quantity, precision: 30, scale: 6, null: false
      t.decimal :held_quantity, precision: 30, scale: 6, null: false
      t.decimal :consumed_quantity, precision: 30, scale: 6, null: false, default: 0
      t.decimal :released_quantity, precision: 30, scale: 6, null: false, default: 0
      t.string :source_type, limit: 48, null: false
      t.uuid :source_id, null: false
      t.string :limit_kind, limit: 16, null: false
      t.decimal :limit_quantity, precision: 30, scale: 6
      t.string :entitlement_key, limit: 96
      t.string :entitlement_state, limit: 24, null: false
      t.string :entitlement_provenance, limit: 32, null: false
      t.string :entitlement_definition_checksum, limit: 64
      t.uuid :entitlement_override_id
      t.uuid :subscription_id
      t.uuid :plan_version_id
      t.bigint :subscription_revision
      t.bigint :finalized_usage_event_id
      t.datetime :admitted_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :finalized_at
      t.datetime :released_at
      t.datetime :expired_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :usage_quota_reservations, :organizations, on_delete: :restrict
    add_foreign_key :usage_quota_reservations, :organizations,
      column: :source_organization_id, on_delete: :restrict,
      name: "fk_usage_quota_reservations_source_organization"
    add_foreign_key :usage_quota_reservations, :usage_windows,
      column: %i[organization_id usage_window_id usage_meter_definition_id],
      primary_key: %i[organization_id id usage_meter_definition_id], on_delete: :restrict,
      name: "fk_usage_quota_reservations_tenant_window_meter"
    add_foreign_key :usage_quota_reservations, :usage_meter_rates,
      column: %i[usage_meter_definition_id usage_meter_rate_id],
      primary_key: %i[usage_meter_definition_id id], on_delete: :restrict,
      name: "fk_usage_quota_reservations_meter_rate"
    add_foreign_key :usage_quota_reservations, :plan_versions, on_delete: :restrict
    add_foreign_key :usage_quota_reservations, :organization_entitlement_overrides,
      column: :entitlement_override_id, on_delete: :restrict,
      name: "fk_usage_quota_reservations_entitlement_override"
    add_foreign_key :usage_quota_reservations, :subscriptions,
      column: %i[organization_id subscription_id plan_version_id],
      primary_key: %i[organization_id id plan_version_id], on_delete: :restrict,
      name: "fk_usage_quota_reservations_subscription_snapshot"

    add_index :usage_quota_reservations, %i[organization_id id], unique: true,
      name: "index_usage_quota_reservations_on_tenant_identity"
    add_index :usage_quota_reservations, %i[organization_id idempotency_key_digest], unique: true,
      name: "index_usage_quota_reservations_on_tenant_idempotency"
    add_index :usage_quota_reservations,
      %i[organization_id usage_window_id state expires_at],
      name: "index_usage_quota_reservations_on_active_pool"
    add_index :usage_quota_reservations,
      %i[organization_id source_type source_id created_at],
      name: "index_usage_quota_reservations_on_tenant_source"
    add_index :usage_quota_reservations, %i[state expires_at],
      where: "state = 'held'", name: "index_usage_quota_reservations_on_stale_holds"
    add_index :usage_quota_reservations, :finalized_usage_event_id, unique: true,
      where: "finalized_usage_event_id IS NOT NULL",
      name: "index_usage_quota_reservations_on_finalized_event"

    add_foreign_key :usage_quota_reservations, :usage_events,
      column: %i[
        organization_id finalized_usage_event_id usage_window_id usage_meter_definition_id
      ],
      primary_key: %i[
        organization_id id usage_window_id usage_meter_definition_id
      ],
      on_delete: :restrict, name: "fk_usage_quota_reservations_finalized_event"

    add_check_constraint :usage_quota_reservations,
      "organization_id = source_organization_id",
      name: "usage_quota_reservations_source_tenant_match"
    add_check_constraint :usage_quota_reservations,
      "idempotency_key_digest ~ '^[0-9a-f]{64}$' AND request_checksum ~ '^[0-9a-f]{64}$'",
      name: "usage_quota_reservations_digest_format"
    add_check_constraint :usage_quota_reservations,
      "state IN ('held', 'finalized', 'released', 'expired')",
      name: "usage_quota_reservations_state_allowlist"
    add_check_constraint :usage_quota_reservations,
      "requested_quantity > 0 AND held_quantity > 0 AND requested_quantity = held_quantity " \
        "AND consumed_quantity >= 0 AND released_quantity >= 0",
      name: "usage_quota_reservations_quantities_nonnegative"
    add_check_constraint :usage_quota_reservations,
      "source_type ~ '^[A-Z][A-Za-z0-9]{0,47}$'",
      name: "usage_quota_reservations_source_type_format"
    add_check_constraint :usage_quota_reservations, <<~SQL.squish, name: "usage_quota_reservations_limit_snapshot_shape"
      (limit_kind = 'unlimited' AND limit_quantity IS NULL AND entitlement_key IS NULL
        AND entitlement_state = 'unlimited' AND entitlement_definition_checksum IS NULL)
      OR (limit_kind = 'capped' AND limit_quantity >= 0
        AND entitlement_key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'
        AND entitlement_state IN ('enabled', 'disabled')
        AND entitlement_definition_checksum ~ '^[0-9a-f]{64}$')
    SQL
    add_check_constraint :usage_quota_reservations,
      "entitlement_provenance ~ '^[a-z][a-z0-9_]{1,31}$'",
      name: "usage_quota_reservations_entitlement_provenance_format"
    add_check_constraint :usage_quota_reservations, <<~SQL.squish, name: "usage_quota_reservations_subscription_snapshot_shape"
      (subscription_id IS NULL AND subscription_revision IS NULL)
      OR (subscription_id IS NOT NULL AND plan_version_id IS NOT NULL AND subscription_revision >= 0)
    SQL
    add_check_constraint :usage_quota_reservations,
      "expires_at > admitted_at",
      name: "usage_quota_reservations_expiry_order"
    add_check_constraint :usage_quota_reservations, <<~SQL.squish, name: "usage_quota_reservations_lifecycle_shape"
      (state = 'held' AND consumed_quantity = 0 AND released_quantity = 0
        AND finalized_usage_event_id IS NULL AND finalized_at IS NULL
        AND released_at IS NULL AND expired_at IS NULL)
      OR (state = 'finalized' AND consumed_quantity + released_quantity = held_quantity
        AND ((consumed_quantity = 0 AND finalized_usage_event_id IS NULL)
          OR (consumed_quantity > 0 AND finalized_usage_event_id IS NOT NULL))
        AND finalized_at IS NOT NULL AND released_at IS NULL AND expired_at IS NULL)
      OR (state = 'released' AND consumed_quantity = 0 AND released_quantity = held_quantity
        AND finalized_usage_event_id IS NULL AND finalized_at IS NULL
        AND released_at IS NOT NULL AND expired_at IS NULL)
      OR (state = 'expired' AND consumed_quantity = 0 AND released_quantity = held_quantity
        AND finalized_usage_event_id IS NULL AND finalized_at IS NULL
        AND released_at IS NULL AND expired_at IS NOT NULL)
    SQL
  end

  def create_operations
    create_table :usage_quota_reservation_operations, id: :bigint do |t|
      t.uuid :organization_id, null: false
      t.uuid :usage_quota_reservation_id, null: false
      t.string :operation_kind, limit: 16, null: false
      t.string :idempotency_key_digest, limit: 64, null: false
      t.string :request_checksum, limit: 64, null: false
      t.decimal :quantity, precision: 30, scale: 6, null: false, default: 0
      t.datetime :requested_expires_at
      t.datetime :created_at, null: false
    end
    add_foreign_key :usage_quota_reservation_operations, :organizations, on_delete: :restrict
    add_foreign_key :usage_quota_reservation_operations, :usage_quota_reservations,
      column: %i[organization_id usage_quota_reservation_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_usage_quota_operations_tenant_reservation"
    add_index :usage_quota_reservation_operations,
      %i[organization_id idempotency_key_digest], unique: true,
      name: "index_usage_quota_operations_on_tenant_idempotency"
    add_index :usage_quota_reservation_operations,
      %i[organization_id usage_quota_reservation_id created_at id],
      name: "index_usage_quota_operations_on_reservation"
    add_check_constraint :usage_quota_reservation_operations,
      "operation_kind IN ('extend', 'finalize', 'release', 'expire')",
      name: "usage_quota_operations_kind_allowlist"
    add_check_constraint :usage_quota_reservation_operations,
      "idempotency_key_digest ~ '^[0-9a-f]{64}$' AND request_checksum ~ '^[0-9a-f]{64}$'",
      name: "usage_quota_operations_digest_format"
    add_check_constraint :usage_quota_reservation_operations,
      "quantity >= 0", name: "usage_quota_operations_quantity_nonnegative"
  end

  def install_pool_lock
    execute <<~SQL
      CREATE FUNCTION lock_usage_quota_pool(reservation_window uuid) RETURNS void AS $$
      DECLARE
        lock_identity text;
      BEGIN
        SELECT concat_ws(':', usage_window.organization_id::text, meter_definition.pool_key,
          meter_definition.billing_unit, COALESCE(meter_definition.quota_entitlement_key, 'unlimited'),
          usage_window.window_policy, usage_window.starts_at::text, usage_window.ends_at::text)
        INTO lock_identity
        FROM usage_windows usage_window
        JOIN usage_meter_definitions meter_definition
          ON meter_definition.id = usage_window.usage_meter_definition_id
        WHERE usage_window.id = reservation_window;

        IF lock_identity IS NULL THEN
          RAISE EXCEPTION 'usage quota window is invalid' USING ERRCODE = '23514';
        END IF;
        PERFORM pg_advisory_xact_lock(hashtextextended(lock_identity, 0));
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def install_reservation_guards
    execute <<~SQL
      CREATE FUNCTION enforce_usage_quota_reservation_lifecycle() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'usage quota reservations cannot be deleted' USING ERRCODE = '23514';
        END IF;

        PERFORM lock_usage_quota_pool(CASE WHEN TG_OP = 'INSERT' THEN NEW.usage_window_id ELSE OLD.usage_window_id END);
        IF TG_OP = 'INSERT' THEN
          RETURN NEW;
        END IF;

        IF OLD.organization_id IS DISTINCT FROM NEW.organization_id OR
          OLD.source_organization_id IS DISTINCT FROM NEW.source_organization_id OR
          OLD.usage_window_id IS DISTINCT FROM NEW.usage_window_id OR
          OLD.usage_meter_definition_id IS DISTINCT FROM NEW.usage_meter_definition_id OR
          OLD.usage_meter_rate_id IS DISTINCT FROM NEW.usage_meter_rate_id OR
          OLD.idempotency_key_digest IS DISTINCT FROM NEW.idempotency_key_digest OR
          OLD.request_checksum IS DISTINCT FROM NEW.request_checksum OR
          OLD.source_type IS DISTINCT FROM NEW.source_type OR OLD.source_id IS DISTINCT FROM NEW.source_id OR
          OLD.limit_kind IS DISTINCT FROM NEW.limit_kind OR OLD.limit_quantity IS DISTINCT FROM NEW.limit_quantity OR
          OLD.entitlement_key IS DISTINCT FROM NEW.entitlement_key OR
          OLD.entitlement_state IS DISTINCT FROM NEW.entitlement_state OR
          OLD.entitlement_provenance IS DISTINCT FROM NEW.entitlement_provenance OR
          OLD.entitlement_definition_checksum IS DISTINCT FROM NEW.entitlement_definition_checksum OR
          OLD.entitlement_override_id IS DISTINCT FROM NEW.entitlement_override_id OR
          OLD.subscription_id IS DISTINCT FROM NEW.subscription_id OR
          OLD.plan_version_id IS DISTINCT FROM NEW.plan_version_id OR
          OLD.subscription_revision IS DISTINCT FROM NEW.subscription_revision OR
          OLD.admitted_at IS DISTINCT FROM NEW.admitted_at OR OLD.created_at IS DISTINCT FROM NEW.created_at THEN
          RAISE EXCEPTION 'usage quota reservation admission snapshot is immutable' USING ERRCODE = '23514';
        END IF;

        IF OLD.state <> 'held' OR NEW.state NOT IN ('held', 'finalized', 'released', 'expired') OR
          NEW.requested_quantity < OLD.requested_quantity OR NEW.held_quantity < OLD.held_quantity OR
          NEW.expires_at < OLD.expires_at THEN
          RAISE EXCEPTION 'usage quota reservation transition is invalid' USING ERRCODE = '23514';
        END IF;
        IF NEW.state = 'finalized' AND NEW.consumed_quantity > 0 AND NOT EXISTS (
          SELECT 1 FROM usage_events event
          WHERE event.id = NEW.finalized_usage_event_id
            AND event.organization_id = NEW.organization_id
            AND event.usage_window_id = NEW.usage_window_id
            AND event.usage_meter_definition_id = NEW.usage_meter_definition_id
            AND event.usage_meter_rate_id = NEW.usage_meter_rate_id
            AND event.source_type = NEW.source_type AND event.source_id = NEW.source_id
            AND event.billed_quantity = NEW.consumed_quantity
        ) THEN
          RAISE EXCEPTION 'usage quota finalization event is inconsistent' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER usage_quota_reservations_lifecycle
      BEFORE INSERT OR UPDATE OR DELETE ON usage_quota_reservations
      FOR EACH ROW EXECUTE FUNCTION enforce_usage_quota_reservation_lifecycle();

      CREATE FUNCTION enforce_usage_quota_reservation_operation_immutability() RETURNS trigger AS $$
      BEGIN
        IF TG_OP <> 'INSERT' THEN
          RAISE EXCEPTION 'usage quota reservation operations are append-only' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER usage_quota_reservation_operations_immutable
      BEFORE UPDATE OR DELETE ON usage_quota_reservation_operations
      FOR EACH ROW EXECUTE FUNCTION enforce_usage_quota_reservation_operation_immutability();
    SQL
  end

  def add_usage_event_pool_lock
    execute usage_event_guard_sql(lock_pool: true)
  end

  def restore_usage_event_guard
    execute usage_event_guard_sql(lock_pool: false)
  end

  def usage_event_guard_sql(lock_pool:)
    quota_lock = lock_pool ? "PERFORM lock_usage_quota_pool(NEW.usage_window_id);" : ""
    <<~SQL
      CREATE OR REPLACE FUNCTION enforce_usage_event_integrity() RETURNS trigger AS $$
      DECLARE
        original usage_events%ROWTYPE;
        corrected numeric;
        event_window usage_windows%ROWTYPE;
      BEGIN
        IF TG_OP <> 'INSERT' THEN
          RAISE EXCEPTION 'usage events are append-only' USING ERRCODE = '23514';
        END IF;

        SELECT * INTO event_window FROM usage_windows WHERE id = NEW.usage_window_id;
        #{quota_lock}
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
    SQL
  end
end
