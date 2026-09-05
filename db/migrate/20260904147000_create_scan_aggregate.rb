# frozen_string_literal: true

class CreateScanAggregate < ActiveRecord::Migration[8.1]
  SCAN_STATUSES = %w[
    requested admitted queued running cancel_requested canceled completed
    partially_completed failed
  ].freeze
  SCAN_TYPES = %w[full targeted verification].freeze
  INITIATOR_TYPES = %w[membership schedule release system].freeze
  EVENT_TYPES = %w[
    scan.requested scan.admitted scan.queued scan.started scan.cancel_requested
    scan.canceled scan.completed scan.partially_completed scan.failed
    scan.progress_recorded
  ].freeze

  def up
    create_scans
    create_scan_events
    connect_policy_snapshots
    extend_deletion_tombstones
    protect_scan_history
  end

  def down
    restore_deletion_tombstones
    remove_foreign_key :crawl_policy_snapshots, name: "fk_crawl_policy_snapshots_exact_scan"
    execute "DROP TRIGGER IF EXISTS scan_events_immutable ON scan_events"
    execute "DROP FUNCTION IF EXISTS protect_scan_event_history()"
    execute "DROP TRIGGER IF EXISTS scans_protect_inputs ON scans"
    execute "DROP FUNCTION IF EXISTS protect_scan_inputs()"
    drop_table :scan_events
    drop_table :scans
  end

  private

  def create_scans
    create_table :scans, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.string :scan_type, limit: 24, null: false
      t.string :initiator_type, limit: 24, null: false
      t.uuid :initiated_by_membership_id
      t.string :status, limit: 32, null: false, default: "requested"
      t.jsonb :settings_snapshot, null: false
      t.string :settings_digest, limit: 64, null: false
      t.jsonb :entitlement_snapshot, null: false
      t.string :entitlement_digest, limit: 64, null: false
      t.string :engine_version, limit: 64, null: false
      t.string :rule_set_version, limit: 64, null: false
      t.integer :configuration_version, null: false, default: 1
      t.uuid :release_id
      t.uuid :baseline_scan_id
      t.integer :targets_count, null: false, default: 0
      t.bigint :urls_discovered_count, null: false, default: 0
      t.bigint :urls_queued_count, null: false, default: 0
      t.bigint :urls_running_count, null: false, default: 0
      t.bigint :urls_processed_count, null: false, default: 0
      t.bigint :urls_succeeded_count, null: false, default: 0
      t.bigint :urls_failed_count, null: false, default: 0
      t.bigint :urls_skipped_count, null: false, default: 0
      t.bigint :findings_count, null: false, default: 0
      t.bigint :progress_sequence, null: false, default: 1
      t.datetime :requested_at, null: false
      t.datetime :admitted_at
      t.datetime :queued_at
      t.datetime :started_at
      t.datetime :cancel_requested_at
      t.datetime :canceled_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.string :failure_category, limit: 64
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :scans, :organizations, on_delete: :restrict
    add_foreign_key :scans, :property_environments,
      column: %i[organization_id project_id property_id environment_id],
      primary_key: %i[organization_id project_id property_id id],
      on_delete: :restrict, name: "fk_scans_exact_environment"
    add_foreign_key :scans, :memberships,
      column: %i[organization_id initiated_by_membership_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_scans_tenant_initiator"
    add_index :scans, %i[organization_id project_id property_id environment_id id],
      unique: true, name: "index_scans_on_exact_identity"
    add_index :scans, %i[organization_id project_id requested_at id],
      order: { requested_at: :desc, id: :desc }, name: "index_scans_on_project_timeline"
    add_index :scans, %i[organization_id project_id status updated_at],
      where: "status IN ('requested', 'admitted', 'queued', 'running', 'cancel_requested')",
      name: "index_scans_on_active_project_work"
    add_index :scans, :release_id, where: "release_id IS NOT NULL"
    add_index :scans, :baseline_scan_id, where: "baseline_scan_id IS NOT NULL"
    add_foreign_key :scans, :scans,
      column: %i[organization_id project_id property_id environment_id baseline_scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_scans_exact_baseline"

    add_check_constraint :scans, "scan_type IN (#{quote_list(SCAN_TYPES)})",
      name: "scans_type_allowlist"
    add_check_constraint :scans, "initiator_type IN (#{quote_list(INITIATOR_TYPES)}) AND " \
      "((initiator_type = 'membership' AND initiated_by_membership_id IS NOT NULL) OR " \
      "(initiator_type <> 'membership' AND initiated_by_membership_id IS NULL))",
      name: "scans_initiator_shape"
    add_check_constraint :scans, "status IN (#{quote_list(SCAN_STATUSES)})",
      name: "scans_status_allowlist"
    add_check_constraint :scans,
      "configuration_version > 0 AND engine_version ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$' " \
        "AND rule_set_version ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'",
      name: "scans_version_provenance"
    add_check_constraint :scans,
      "jsonb_typeof(settings_snapshot) = 'object' AND octet_length(settings_snapshot::text) <= 32768 " \
        "AND jsonb_typeof(entitlement_snapshot) = 'object' " \
        "AND octet_length(entitlement_snapshot::text) <= 32768",
      name: "scans_bounded_snapshots"
    add_check_constraint :scans,
      "settings_digest ~ '^[0-9a-f]{64}$' AND entitlement_digest ~ '^[0-9a-f]{64}$'",
      name: "scans_snapshot_digests"
    add_check_constraint :scans, "baseline_scan_id IS NULL OR baseline_scan_id <> id",
      name: "scans_distinct_baseline"
    add_check_constraint :scans, counter_constraint, name: "scans_counter_consistency"
    add_check_constraint :scans, lifecycle_constraint, name: "scans_lifecycle_shape"
  end

  def create_scan_events
    create_table :scan_events, id: :bigint do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :scan_id, null: false
      t.bigint :sequence, null: false
      t.string :event_type, limit: 40, null: false
      t.string :from_status, limit: 32
      t.string :to_status, limit: 32, null: false
      t.uuid :actor_membership_id
      t.string :idempotency_key_digest, limit: 64, null: false
      t.string :payload_digest, limit: 64, null: false
      t.integer :targets_count, null: false
      t.bigint :urls_discovered_count, null: false
      t.bigint :urls_queued_count, null: false
      t.bigint :urls_running_count, null: false
      t.bigint :urls_processed_count, null: false
      t.bigint :urls_succeeded_count, null: false
      t.bigint :urls_failed_count, null: false
      t.bigint :urls_skipped_count, null: false
      t.bigint :findings_count, null: false
      t.string :failure_category, limit: 64
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
    end

    add_foreign_key :scan_events, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_scan_events_exact_scan"
    add_foreign_key :scan_events, :memberships,
      column: %i[organization_id actor_membership_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_scan_events_tenant_actor"
    add_index :scan_events, %i[scan_id sequence], unique: true,
      name: "index_scan_events_on_sequence"
    add_index :scan_events, %i[scan_id idempotency_key_digest], unique: true,
      name: "index_scan_events_on_idempotency"
    add_index :scan_events, %i[organization_id project_id scan_id occurred_at],
      name: "index_scan_events_on_project_timeline"
    add_check_constraint :scan_events, "sequence > 0", name: "scan_events_positive_sequence"
    add_check_constraint :scan_events, "event_type IN (#{quote_list(EVENT_TYPES)})",
      name: "scan_events_type_allowlist"
    add_check_constraint :scan_events,
      "(from_status IS NULL OR from_status IN (#{quote_list(SCAN_STATUSES)})) " \
        "AND to_status IN (#{quote_list(SCAN_STATUSES)})",
      name: "scan_events_status_allowlist"
    add_check_constraint :scan_events,
      "idempotency_key_digest ~ '^[0-9a-f]{64}$' AND payload_digest ~ '^[0-9a-f]{64}$'",
      name: "scan_events_digest_shape"
    add_check_constraint :scan_events, event_counter_constraint,
      name: "scan_events_counter_consistency"
    add_check_constraint :scan_events,
      "failure_category IS NULL OR failure_category ~ '^[a-z][a-z0-9_]{0,63}$'",
      name: "scan_events_failure_category"
  end

  def connect_policy_snapshots
    add_foreign_key :crawl_policy_snapshots, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, validate: false,
      name: "fk_crawl_policy_snapshots_exact_scan"
  end

  def extend_deletion_tombstones
    remove_check_constraint :audit_target_tombstones, name: "audit_tombstones_target_type"
    add_check_constraint :audit_target_tombstones,
      "target_type IN ('Project', 'Property', 'PropertyEnvironment', 'DomainVerification', 'CrawlPolicy', 'Scan')",
      name: "audit_tombstones_target_type"
  end

  def restore_deletion_tombstones
    remove_check_constraint :audit_target_tombstones, name: "audit_tombstones_target_type"
    add_check_constraint :audit_target_tombstones,
      "target_type IN ('Project', 'Property', 'PropertyEnvironment', 'DomainVerification', 'CrawlPolicy')",
      name: "audit_tombstones_target_type"
  end

  def protect_scan_history
    execute <<~SQL
      CREATE FUNCTION protect_scan_inputs() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN
            RETURN OLD;
          END IF;
          RAISE EXCEPTION 'scan deletion requires an active lifecycle workflow';
        END IF;

        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.scan_type IS DISTINCT FROM OLD.scan_type
          OR NEW.initiator_type IS DISTINCT FROM OLD.initiator_type
          OR NEW.initiated_by_membership_id IS DISTINCT FROM OLD.initiated_by_membership_id
          OR NEW.settings_snapshot IS DISTINCT FROM OLD.settings_snapshot
          OR NEW.settings_digest IS DISTINCT FROM OLD.settings_digest
          OR NEW.entitlement_snapshot IS DISTINCT FROM OLD.entitlement_snapshot
          OR NEW.entitlement_digest IS DISTINCT FROM OLD.entitlement_digest
          OR NEW.engine_version IS DISTINCT FROM OLD.engine_version
          OR NEW.rule_set_version IS DISTINCT FROM OLD.rule_set_version
          OR NEW.configuration_version IS DISTINCT FROM OLD.configuration_version
          OR NEW.release_id IS DISTINCT FROM OLD.release_id
          OR NEW.baseline_scan_id IS DISTINCT FROM OLD.baseline_scan_id
          OR NEW.requested_at IS DISTINCT FROM OLD.requested_at THEN
          RAISE EXCEPTION 'scan input and provenance are immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER scans_protect_inputs
      BEFORE UPDATE OR DELETE ON scans
      FOR EACH ROW EXECUTE FUNCTION protect_scan_inputs();

      CREATE FUNCTION protect_scan_event_history() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN
          RETURN OLD;
        END IF;
        RAISE EXCEPTION 'scan events are append-only';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER scan_events_immutable
      BEFORE UPDATE OR DELETE ON scan_events
      FOR EACH ROW EXECUTE FUNCTION protect_scan_event_history();
    SQL
  end

  def counter_constraint
    <<~SQL.squish
      targets_count >= 0 AND urls_discovered_count >= 0 AND urls_queued_count >= 0
      AND urls_running_count >= 0 AND urls_processed_count >= 0
      AND urls_succeeded_count >= 0 AND urls_failed_count >= 0
      AND urls_skipped_count >= 0 AND findings_count >= 0 AND progress_sequence > 0
      AND urls_processed_count = urls_succeeded_count + urls_failed_count + urls_skipped_count
      AND urls_discovered_count >= urls_processed_count + urls_queued_count + urls_running_count
      AND (status NOT IN ('canceled', 'completed', 'partially_completed', 'failed')
        OR (urls_queued_count = 0 AND urls_running_count = 0))
    SQL
  end

  def event_counter_constraint
    <<~SQL.squish
      targets_count >= 0 AND urls_discovered_count >= 0 AND urls_queued_count >= 0
      AND urls_running_count >= 0 AND urls_processed_count >= 0
      AND urls_succeeded_count >= 0 AND urls_failed_count >= 0
      AND urls_skipped_count >= 0 AND findings_count >= 0
      AND urls_processed_count = urls_succeeded_count + urls_failed_count + urls_skipped_count
      AND urls_discovered_count >= urls_processed_count + urls_queued_count + urls_running_count
    SQL
  end

  def lifecycle_constraint
    <<~SQL.squish
      requested_at IS NOT NULL
      AND (admitted_at IS NULL OR admitted_at >= requested_at)
      AND (queued_at IS NULL OR (admitted_at IS NOT NULL AND queued_at >= admitted_at))
      AND (started_at IS NULL OR (queued_at IS NOT NULL AND started_at >= queued_at))
      AND (cancel_requested_at IS NULL OR cancel_requested_at >= requested_at)
      AND (canceled_at IS NULL OR (cancel_requested_at IS NOT NULL AND canceled_at >= cancel_requested_at))
      AND (completed_at IS NULL OR (started_at IS NOT NULL AND completed_at >= started_at))
      AND (failed_at IS NULL OR failed_at >= requested_at)
      AND (
        (status = 'requested' AND admitted_at IS NULL AND queued_at IS NULL AND started_at IS NULL
          AND cancel_requested_at IS NULL AND canceled_at IS NULL AND completed_at IS NULL
          AND failed_at IS NULL AND failure_category IS NULL)
        OR (status = 'admitted' AND admitted_at IS NOT NULL AND queued_at IS NULL AND started_at IS NULL
          AND cancel_requested_at IS NULL AND canceled_at IS NULL AND completed_at IS NULL
          AND failed_at IS NULL AND failure_category IS NULL)
        OR (status = 'queued' AND admitted_at IS NOT NULL AND queued_at IS NOT NULL AND started_at IS NULL
          AND cancel_requested_at IS NULL AND canceled_at IS NULL AND completed_at IS NULL
          AND failed_at IS NULL AND failure_category IS NULL)
        OR (status = 'running' AND admitted_at IS NOT NULL AND queued_at IS NOT NULL AND started_at IS NOT NULL
          AND cancel_requested_at IS NULL AND canceled_at IS NULL AND completed_at IS NULL
          AND failed_at IS NULL AND failure_category IS NULL)
        OR (status = 'cancel_requested' AND admitted_at IS NOT NULL AND queued_at IS NOT NULL
          AND cancel_requested_at IS NOT NULL AND canceled_at IS NULL AND completed_at IS NULL
          AND failed_at IS NULL AND failure_category IS NULL)
        OR (status = 'canceled' AND cancel_requested_at IS NOT NULL AND canceled_at IS NOT NULL
          AND completed_at IS NULL AND failed_at IS NULL AND failure_category IS NULL)
        OR (status IN ('completed', 'partially_completed') AND started_at IS NOT NULL
          AND completed_at IS NOT NULL AND canceled_at IS NULL AND failed_at IS NULL
          AND failure_category IS NULL)
        OR (status = 'failed' AND failed_at IS NOT NULL AND completed_at IS NULL AND canceled_at IS NULL
          AND failure_category ~ '^[a-z][a-z0-9_]{0,63}$')
      )
    SQL
  end

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
