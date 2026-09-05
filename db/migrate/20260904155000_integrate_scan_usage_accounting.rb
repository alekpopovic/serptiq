# frozen_string_literal: true

class IntegrateScanUsageAccounting < ActiveRecord::Migration[8.1]
  def up
    add_index :usage_events, %i[organization_id id], unique: true,
      name: "index_usage_events_on_tenant_identity"
    create_quota_allocations
    extend_reservation_operations
    relax_reservation_lifecycle
    create_scan_usage_operations
    install_allocation_guards
    install_scan_usage_guards
  end

  def down
    execute "DROP TRIGGER IF EXISTS crawl_scan_usage_operations_lifecycle ON crawl_scan_usage_operations"
    execute "DROP FUNCTION IF EXISTS enforce_crawl_scan_usage_operation_lifecycle()"
    execute "DROP TRIGGER IF EXISTS usage_quota_allocations_lifecycle ON usage_quota_allocations"
    execute "DROP FUNCTION IF EXISTS enforce_usage_quota_allocation_lifecycle()"
    drop_table :crawl_scan_usage_operations
    restore_reservation_lifecycle
    restore_reservation_operations
    drop_table :usage_quota_allocations
    remove_index :usage_events, name: "index_usage_events_on_tenant_identity"
  end

  private

  def create_quota_allocations
    create_table :usage_quota_allocations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :usage_quota_reservation_id, null: false
      t.uuid :usage_window_id, null: false
      t.uuid :usage_meter_definition_id, null: false
      t.uuid :usage_meter_rate_id, null: false
      t.string :idempotency_key_digest, limit: 64, null: false
      t.string :request_checksum, limit: 64, null: false
      t.string :completion_key_digest, limit: 64
      t.string :completion_checksum, limit: 64
      t.string :state, limit: 16, null: false
      t.decimal :quantity, precision: 24, scale: 6, null: false
      t.decimal :applied_weight, precision: 18, scale: 6, null: false
      t.decimal :billed_quantity, precision: 30, scale: 6, null: false
      t.string :source_type, limit: 48, null: false
      t.uuid :source_id, null: false
      t.bigint :usage_event_id
      t.datetime :allocated_at, null: false
      t.datetime :completed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :usage_quota_allocations, :organizations, on_delete: :restrict
    add_foreign_key :usage_quota_allocations, :usage_quota_reservations,
      column: %i[organization_id usage_quota_reservation_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_usage_quota_allocations_tenant_reservation"
    add_foreign_key :usage_quota_allocations, :usage_windows,
      column: %i[organization_id usage_window_id usage_meter_definition_id],
      primary_key: %i[organization_id id usage_meter_definition_id], on_delete: :restrict,
      name: "fk_usage_quota_allocations_tenant_window"
    add_foreign_key :usage_quota_allocations, :usage_meter_rates,
      column: %i[usage_meter_definition_id usage_meter_rate_id],
      primary_key: %i[usage_meter_definition_id id], on_delete: :restrict,
      name: "fk_usage_quota_allocations_meter_rate"
    add_foreign_key :usage_quota_allocations, :usage_events,
      column: %i[organization_id usage_event_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_usage_quota_allocations_tenant_event"

    add_index :usage_quota_allocations, %i[organization_id id], unique: true,
      name: "index_usage_quota_allocations_on_tenant_identity"
    add_index :usage_quota_allocations, %i[organization_id idempotency_key_digest], unique: true,
      name: "index_usage_quota_allocations_on_tenant_idempotency"
    add_index :usage_quota_allocations,
      %i[organization_id usage_quota_reservation_id state allocated_at id],
      name: "index_usage_quota_allocations_on_reservation"
    add_index :usage_quota_allocations, :usage_event_id, unique: true,
      where: "usage_event_id IS NOT NULL", name: "index_usage_quota_allocations_on_event"

    add_check_constraint :usage_quota_allocations,
      "idempotency_key_digest ~ '^[0-9a-f]{64}$' AND request_checksum ~ '^[0-9a-f]{64}$' " \
        "AND (completion_key_digest IS NULL OR completion_key_digest ~ '^[0-9a-f]{64}$') " \
        "AND (completion_checksum IS NULL OR completion_checksum ~ '^[0-9a-f]{64}$')",
      name: "usage_quota_allocations_digest_shape"
    add_check_constraint :usage_quota_allocations,
      "state IN ('held', 'consumed', 'released')",
      name: "usage_quota_allocations_state_allowlist"
    add_check_constraint :usage_quota_allocations,
      "quantity > 0 AND applied_weight > 0 AND billed_quantity = quantity * applied_weight",
      name: "usage_quota_allocations_weighted_quantity"
    add_check_constraint :usage_quota_allocations,
      "source_type ~ '^[A-Z][A-Za-z0-9]{0,47}$'",
      name: "usage_quota_allocations_source_type_format"
    add_check_constraint :usage_quota_allocations, <<~SQL.squish, name: "usage_quota_allocations_lifecycle_shape"
      (state = 'held' AND completion_key_digest IS NULL AND completion_checksum IS NULL
        AND usage_event_id IS NULL AND completed_at IS NULL)
      OR (state = 'consumed' AND completion_key_digest IS NOT NULL AND completion_checksum IS NOT NULL
        AND usage_event_id IS NOT NULL AND completed_at IS NOT NULL)
      OR (state = 'released' AND completion_key_digest IS NOT NULL AND completion_checksum IS NOT NULL
        AND usage_event_id IS NULL AND completed_at IS NOT NULL)
    SQL
  end

  def extend_reservation_operations
    add_column :usage_quota_reservation_operations, :usage_event_id, :bigint
    add_foreign_key :usage_quota_reservation_operations, :usage_events,
      column: %i[organization_id usage_event_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_usage_quota_operations_tenant_event"
    add_index :usage_quota_reservation_operations, :usage_event_id, unique: true,
      where: "usage_event_id IS NOT NULL", name: "index_usage_quota_operations_on_event"
    remove_check_constraint :usage_quota_reservation_operations,
      name: "usage_quota_operations_kind_allowlist"
    add_check_constraint :usage_quota_reservation_operations,
      "operation_kind IN ('extend', 'finalize', 'release', 'expire')",
      name: "usage_quota_operations_kind_allowlist"
    add_check_constraint :usage_quota_reservation_operations,
      "(operation_kind = 'finalize') OR usage_event_id IS NULL",
      name: "usage_quota_operations_event_shape"
  end

  def restore_reservation_operations
    remove_foreign_key :usage_quota_reservation_operations,
      name: "fk_usage_quota_operations_tenant_event"
    remove_check_constraint :usage_quota_reservation_operations,
      name: "usage_quota_operations_event_shape"
    remove_column :usage_quota_reservation_operations, :usage_event_id
  end

  def relax_reservation_lifecycle
    remove_check_constraint :usage_quota_reservations,
      name: "usage_quota_reservations_quantities_nonnegative"
    remove_check_constraint :usage_quota_reservations,
      name: "usage_quota_reservations_lifecycle_shape"
    add_check_constraint :usage_quota_reservations,
      "requested_quantity > 0 AND held_quantity > 0 AND requested_quantity = held_quantity " \
        "AND consumed_quantity >= 0 AND consumed_quantity <= held_quantity " \
        "AND released_quantity >= 0 AND released_quantity <= held_quantity",
      name: "usage_quota_reservations_quantities_nonnegative"
    add_check_constraint :usage_quota_reservations, reservation_lifecycle_constraint,
      name: "usage_quota_reservations_lifecycle_shape"
    execute reservation_guard_sql(partial_consumption: true)
  end

  def restore_reservation_lifecycle
    remove_check_constraint :usage_quota_reservations,
      name: "usage_quota_reservations_quantities_nonnegative"
    remove_check_constraint :usage_quota_reservations,
      name: "usage_quota_reservations_lifecycle_shape"
    add_check_constraint :usage_quota_reservations,
      "requested_quantity > 0 AND held_quantity > 0 AND requested_quantity = held_quantity " \
        "AND consumed_quantity >= 0 AND released_quantity >= 0",
      name: "usage_quota_reservations_quantities_nonnegative"
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
    execute reservation_guard_sql(partial_consumption: false)
  end

  def reservation_lifecycle_constraint
    <<~SQL.squish
      (state = 'held' AND released_quantity = 0 AND finalized_usage_event_id IS NULL
        AND finalized_at IS NULL AND released_at IS NULL AND expired_at IS NULL)
      OR (state = 'finalized' AND consumed_quantity + released_quantity = held_quantity
        AND finalized_at IS NOT NULL AND released_at IS NULL AND expired_at IS NULL)
      OR (state = 'released' AND consumed_quantity = 0 AND released_quantity = held_quantity
        AND finalized_usage_event_id IS NULL AND finalized_at IS NULL
        AND released_at IS NOT NULL AND expired_at IS NULL)
      OR (state = 'expired' AND consumed_quantity + released_quantity = held_quantity
        AND finalized_usage_event_id IS NULL AND finalized_at IS NULL
        AND released_at IS NULL AND expired_at IS NOT NULL)
    SQL
  end

  def reservation_guard_sql(partial_consumption:)
    final_event_check = if partial_consumption
      <<~SQL.squish
        IF NEW.state = 'finalized' AND NEW.finalized_usage_event_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM usage_events event
          WHERE event.id = NEW.finalized_usage_event_id
            AND event.organization_id = NEW.organization_id
            AND event.source_type = NEW.source_type AND event.source_id = NEW.source_id
            AND event.billed_quantity <= NEW.consumed_quantity
        ) THEN
          RAISE EXCEPTION 'usage quota finalization event is inconsistent' USING ERRCODE = '23514';
        END IF;
      SQL
    else
      <<~SQL.squish
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
      SQL
    end
    consumed_transition = partial_consumption ? "NEW.consumed_quantity < OLD.consumed_quantity OR" : ""

    <<~SQL
      CREATE OR REPLACE FUNCTION enforce_usage_quota_reservation_lifecycle() RETURNS trigger AS $$
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
          #{consumed_transition}
          NEW.expires_at < OLD.expires_at THEN
          RAISE EXCEPTION 'usage quota reservation transition is invalid' USING ERRCODE = '23514';
        END IF;
        #{final_event_check}
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def create_scan_usage_operations
    create_table :crawl_scan_usage_operations, id: :bigint do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :scan_id, null: false
      t.uuid :usage_quota_allocation_id
      t.bigint :usage_event_id
      t.string :operation_kind, limit: 32, null: false
      t.string :meter_key, limit: 96
      t.integer :meter_rate_version
      t.decimal :applied_weight, precision: 18, scale: 6
      t.decimal :reserved_credits, precision: 30, scale: 6, null: false, default: 0
      t.string :source_key_digest, limit: 64, null: false
      t.string :request_checksum, limit: 64, null: false
      t.string :completion_checksum, limit: 64
      t.string :state, limit: 24, null: false
      t.string :outcome, limit: 24
      t.jsonb :metadata, null: false, default: {}
      t.datetime :attempted_at, null: false
      t.datetime :finished_at
      t.timestamps
    end

    add_foreign_key :crawl_scan_usage_operations, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_crawl_scan_usage_operations_exact_scan"
    add_foreign_key :crawl_scan_usage_operations, :usage_quota_allocations,
      column: %i[organization_id usage_quota_allocation_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_crawl_scan_usage_operations_tenant_allocation"
    add_foreign_key :crawl_scan_usage_operations, :usage_events,
      column: %i[organization_id usage_event_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_crawl_scan_usage_operations_tenant_event"

    add_index :crawl_scan_usage_operations,
      %i[organization_id scan_id source_key_digest], unique: true,
      name: "index_crawl_scan_usage_operations_on_source"
    add_index :crawl_scan_usage_operations,
      %i[organization_id scan_id operation_kind state attempted_at id],
      name: "index_crawl_scan_usage_operations_on_breakdown"
    add_index :crawl_scan_usage_operations, :usage_quota_allocation_id, unique: true,
      where: "usage_quota_allocation_id IS NOT NULL",
      name: "index_crawl_scan_usage_operations_on_allocation"
    add_index :crawl_scan_usage_operations, :usage_event_id, unique: true,
      where: "usage_event_id IS NOT NULL", name: "index_crawl_scan_usage_operations_on_event"
    add_index :crawl_scan_usage_operations, %i[state attempted_at id],
      where: "state = 'reserved'", name: "index_crawl_scan_usage_operations_on_recovery"

    add_check_constraint :crawl_scan_usage_operations,
      "operation_kind IN ('http_fetch', 'rendered_page', 'lighthouse_page', 'artifact')",
      name: "crawl_scan_usage_operations_kind_allowlist"
    add_check_constraint :crawl_scan_usage_operations,
      "state IN ('reserved', 'billed', 'not_billable') AND " \
        "(outcome IS NULL OR outcome IN ('accepted', 'failed', 'canceled', 'rejected', 'abandoned'))",
      name: "crawl_scan_usage_operations_state_allowlist"
    add_check_constraint :crawl_scan_usage_operations,
      "source_key_digest ~ '^[0-9a-f]{64}$' AND request_checksum ~ '^[0-9a-f]{64}$' " \
        "AND (completion_checksum IS NULL OR completion_checksum ~ '^[0-9a-f]{64}$')",
      name: "crawl_scan_usage_operations_digest_shape"
    add_check_constraint :crawl_scan_usage_operations,
      "jsonb_typeof(metadata) = 'object' AND pg_column_size(metadata) <= 4096",
      name: "crawl_scan_usage_operations_metadata_shape"
    add_check_constraint :crawl_scan_usage_operations, <<~SQL.squish, name: "crawl_scan_usage_operations_meter_shape"
      (operation_kind = 'artifact' AND meter_key IS NULL AND meter_rate_version IS NULL
        AND applied_weight IS NULL AND reserved_credits = 0 AND usage_quota_allocation_id IS NULL)
      OR (operation_kind <> 'artifact' AND meter_key IS NOT NULL AND meter_rate_version > 0
        AND applied_weight > 0 AND reserved_credits = applied_weight
        AND usage_quota_allocation_id IS NOT NULL)
    SQL
    add_check_constraint :crawl_scan_usage_operations, <<~SQL.squish, name: "crawl_scan_usage_operations_lifecycle_shape"
      (state = 'reserved' AND outcome IS NULL AND completion_checksum IS NULL
        AND usage_event_id IS NULL AND finished_at IS NULL)
      OR (state = 'billed' AND operation_kind <> 'artifact' AND outcome = 'accepted'
        AND completion_checksum IS NOT NULL AND usage_event_id IS NOT NULL AND finished_at IS NOT NULL)
      OR (state = 'not_billable' AND completion_checksum IS NOT NULL
        AND usage_event_id IS NULL AND outcome IS NOT NULL AND finished_at IS NOT NULL
        AND (operation_kind = 'artifact' OR outcome <> 'accepted'))
    SQL
  end

  def install_allocation_guards
    execute <<~SQL
      CREATE FUNCTION enforce_usage_quota_allocation_lifecycle() RETURNS trigger AS $$
      DECLARE
        reservation usage_quota_reservations%ROWTYPE;
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'usage quota allocations cannot be deleted' USING ERRCODE = '23514';
        END IF;

        SELECT * INTO reservation FROM usage_quota_reservations
          WHERE id = CASE WHEN TG_OP = 'INSERT' THEN NEW.usage_quota_reservation_id ELSE OLD.usage_quota_reservation_id END;
        PERFORM lock_usage_quota_pool(reservation.usage_window_id);

        IF TG_OP = 'INSERT' THEN
          IF reservation.id IS NULL OR reservation.organization_id <> NEW.organization_id OR
            reservation.source_type <> NEW.source_type OR reservation.source_id <> NEW.source_id OR
            NOT EXISTS (
              SELECT 1
              FROM usage_windows target_window
              JOIN usage_meter_definitions target_meter
                ON target_meter.id = target_window.usage_meter_definition_id
              JOIN usage_windows anchor_window ON anchor_window.id = reservation.usage_window_id
              JOIN usage_meter_definitions anchor_meter
                ON anchor_meter.id = anchor_window.usage_meter_definition_id
              WHERE target_window.id = NEW.usage_window_id
                AND target_window.organization_id = reservation.organization_id
                AND target_window.starts_at = anchor_window.starts_at
                AND target_window.ends_at = anchor_window.ends_at
                AND target_meter.pool_key = anchor_meter.pool_key
                AND target_meter.billing_unit = anchor_meter.billing_unit
                AND target_meter.quota_entitlement_key IS NOT DISTINCT FROM anchor_meter.quota_entitlement_key
                AND target_meter.window_policy = anchor_meter.window_policy
            ) THEN
            RAISE EXCEPTION 'usage quota allocation reservation context is invalid' USING ERRCODE = '23514';
          END IF;
          RETURN NEW;
        END IF;

        IF OLD.organization_id IS DISTINCT FROM NEW.organization_id OR
          OLD.usage_quota_reservation_id IS DISTINCT FROM NEW.usage_quota_reservation_id OR
          OLD.usage_window_id IS DISTINCT FROM NEW.usage_window_id OR
          OLD.usage_meter_definition_id IS DISTINCT FROM NEW.usage_meter_definition_id OR
          OLD.usage_meter_rate_id IS DISTINCT FROM NEW.usage_meter_rate_id OR
          OLD.idempotency_key_digest IS DISTINCT FROM NEW.idempotency_key_digest OR
          OLD.request_checksum IS DISTINCT FROM NEW.request_checksum OR
          OLD.quantity IS DISTINCT FROM NEW.quantity OR OLD.applied_weight IS DISTINCT FROM NEW.applied_weight OR
          OLD.billed_quantity IS DISTINCT FROM NEW.billed_quantity OR
          OLD.source_type IS DISTINCT FROM NEW.source_type OR OLD.source_id IS DISTINCT FROM NEW.source_id OR
          OLD.allocated_at IS DISTINCT FROM NEW.allocated_at OR OLD.created_at IS DISTINCT FROM NEW.created_at OR
          OLD.state <> 'held' OR NEW.state NOT IN ('consumed', 'released') THEN
          RAISE EXCEPTION 'usage quota allocation transition is invalid' USING ERRCODE = '23514';
        END IF;

        IF NEW.state = 'consumed' AND NOT EXISTS (
          SELECT 1 FROM usage_events event
          WHERE event.id = NEW.usage_event_id AND event.organization_id = NEW.organization_id
            AND event.usage_window_id = NEW.usage_window_id
            AND event.usage_meter_definition_id = NEW.usage_meter_definition_id
            AND event.usage_meter_rate_id = NEW.usage_meter_rate_id
            AND event.source_type = NEW.source_type AND event.source_id = NEW.source_id
            AND event.quantity = NEW.quantity AND event.applied_weight = NEW.applied_weight
            AND event.billed_quantity = NEW.billed_quantity
        ) THEN
          RAISE EXCEPTION 'usage quota allocation event is inconsistent' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER usage_quota_allocations_lifecycle
      BEFORE INSERT OR UPDATE OR DELETE ON usage_quota_allocations
      FOR EACH ROW EXECUTE FUNCTION enforce_usage_quota_allocation_lifecycle();
    SQL
  end

  def install_scan_usage_guards
    execute <<~SQL
      CREATE FUNCTION enforce_crawl_scan_usage_operation_lifecycle() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN
            RETURN OLD;
          END IF;
          RAISE EXCEPTION 'scan usage operations require lifecycle deletion' USING ERRCODE = '23514';
        END IF;
        IF TG_OP = 'INSERT' THEN
          IF NEW.operation_kind <> 'artifact' AND NOT EXISTS (
            SELECT 1
            FROM usage_quota_allocations allocation
            JOIN usage_meter_definitions meter
              ON meter.id = allocation.usage_meter_definition_id
            JOIN usage_meter_rates rate ON rate.id = allocation.usage_meter_rate_id
            WHERE allocation.id = NEW.usage_quota_allocation_id
              AND allocation.organization_id = NEW.organization_id
              AND allocation.source_type = 'Scan' AND allocation.source_id = NEW.scan_id
              AND allocation.state = 'held' AND meter.key = NEW.meter_key
              AND rate.version = NEW.meter_rate_version
              AND allocation.applied_weight = NEW.applied_weight
              AND allocation.billed_quantity = NEW.reserved_credits
          ) THEN
            RAISE EXCEPTION 'scan usage operation allocation is inconsistent' USING ERRCODE = '23514';
          END IF;
          RETURN NEW;
        END IF;
        IF OLD.organization_id IS DISTINCT FROM NEW.organization_id OR
          OLD.project_id IS DISTINCT FROM NEW.project_id OR OLD.property_id IS DISTINCT FROM NEW.property_id OR
          OLD.environment_id IS DISTINCT FROM NEW.environment_id OR OLD.scan_id IS DISTINCT FROM NEW.scan_id OR
          OLD.usage_quota_allocation_id IS DISTINCT FROM NEW.usage_quota_allocation_id OR
          OLD.operation_kind IS DISTINCT FROM NEW.operation_kind OR OLD.meter_key IS DISTINCT FROM NEW.meter_key OR
          OLD.meter_rate_version IS DISTINCT FROM NEW.meter_rate_version OR
          OLD.applied_weight IS DISTINCT FROM NEW.applied_weight OR
          OLD.reserved_credits IS DISTINCT FROM NEW.reserved_credits OR
          OLD.source_key_digest IS DISTINCT FROM NEW.source_key_digest OR
          OLD.request_checksum IS DISTINCT FROM NEW.request_checksum OR
          OLD.attempted_at IS DISTINCT FROM NEW.attempted_at OR OLD.created_at IS DISTINCT FROM NEW.created_at OR
          OLD.state <> 'reserved' OR NEW.state NOT IN ('billed', 'not_billable') THEN
          RAISE EXCEPTION 'scan usage operation transition is invalid' USING ERRCODE = '23514';
        END IF;
        IF NEW.state = 'billed' AND NOT EXISTS (
          SELECT 1 FROM usage_quota_allocations allocation
          WHERE allocation.id = NEW.usage_quota_allocation_id
            AND allocation.organization_id = NEW.organization_id
            AND allocation.state = 'consumed' AND allocation.usage_event_id = NEW.usage_event_id
        ) THEN
          RAISE EXCEPTION 'scan usage operation event is inconsistent' USING ERRCODE = '23514';
        END IF;
        IF NEW.state = 'not_billable' AND NEW.usage_quota_allocation_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM usage_quota_allocations allocation
          WHERE allocation.id = NEW.usage_quota_allocation_id
            AND allocation.organization_id = NEW.organization_id AND allocation.state = 'released'
        ) THEN
          RAISE EXCEPTION 'scan usage operation release is inconsistent' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_scan_usage_operations_lifecycle
      BEFORE INSERT OR UPDATE OR DELETE ON crawl_scan_usage_operations
      FOR EACH ROW EXECUTE FUNCTION enforce_crawl_scan_usage_operation_lifecycle();
    SQL
  end
end
