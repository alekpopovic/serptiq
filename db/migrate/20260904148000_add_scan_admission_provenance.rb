# frozen_string_literal: true

class AddScanAdmissionProvenance < ActiveRecord::Migration[8.1]
  ACTIVE_STATUSES = %w[admitted queued running cancel_requested].freeze

  def up
    change_table :scans, bulk: true do |t|
      t.string :request_source, limit: 24
      t.string :request_idempotency_digest, limit: 64
      t.string :request_checksum, limit: 64
      t.integer :admission_version
      t.uuid :usage_quota_reservation_id
      t.uuid :domain_verification_id
      t.datetime :preflight_checked_at
      t.integer :preflight_status_code
      t.string :preflight_destination_digest, limit: 64
      t.decimal :credit_estimate, precision: 30, scale: 6
      t.datetime :dispatch_attempted_at
      t.datetime :dispatch_enqueued_at
      t.integer :dispatch_attempt_count, null: false, default: 0
      t.string :dispatch_last_error_category, limit: 64
    end

    add_index :scans, %i[organization_id request_idempotency_digest], unique: true,
      where: "request_idempotency_digest IS NOT NULL",
      name: "index_scans_on_tenant_admission_idempotency"
    add_index :scans, %i[organization_id status],
      where: active_predicate, name: "index_scans_on_active_organization_work"
    add_index :scans, %i[organization_id project_id status],
      where: active_predicate, name: "index_scans_on_active_project_admissions"
    add_index :scans, :status,
      where: active_predicate, name: "index_scans_on_active_global_work"
    add_index :scans, %i[status dispatch_enqueued_at admitted_at],
      where: "status = 'admitted' AND dispatch_enqueued_at IS NULL",
      name: "index_scans_on_pending_dispatch"

    add_foreign_key :scans, :usage_quota_reservations,
      column: %i[organization_id usage_quota_reservation_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_scans_tenant_quota_reservation"
    add_foreign_key :scans, :domain_verifications,
      column: %i[organization_id project_id property_id environment_id domain_verification_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_scans_exact_verification"

    add_check_constraint :scans, admission_shape,
      name: "scans_admission_provenance_shape"
    add_check_constraint :scans, dispatch_shape,
      name: "scans_dispatch_shape"
    replace_input_guard(include_admission: true)
  end

  def down
    replace_input_guard(include_admission: false)
    remove_check_constraint :scans, name: "scans_dispatch_shape"
    remove_check_constraint :scans, name: "scans_admission_provenance_shape"
    remove_foreign_key :scans, name: "fk_scans_exact_verification"
    remove_foreign_key :scans, name: "fk_scans_tenant_quota_reservation"
    remove_index :scans, name: "index_scans_on_pending_dispatch"
    remove_index :scans, name: "index_scans_on_active_global_work"
    remove_index :scans, name: "index_scans_on_active_project_admissions"
    remove_index :scans, name: "index_scans_on_active_organization_work"
    remove_index :scans, name: "index_scans_on_tenant_admission_idempotency"
    remove_columns :scans,
      :request_source, :request_idempotency_digest, :request_checksum, :admission_version,
      :usage_quota_reservation_id, :domain_verification_id, :preflight_checked_at,
      :preflight_status_code, :preflight_destination_digest, :credit_estimate,
      :dispatch_attempted_at, :dispatch_enqueued_at, :dispatch_attempt_count,
      :dispatch_last_error_category
  end

  private

  def active_predicate
    "status IN (#{quote_list(ACTIVE_STATUSES)})"
  end

  def admission_shape
    <<~SQL.squish
      (admission_version IS NULL AND request_source IS NULL
        AND request_idempotency_digest IS NULL AND request_checksum IS NULL
        AND usage_quota_reservation_id IS NULL AND domain_verification_id IS NULL
        AND preflight_checked_at IS NULL AND preflight_status_code IS NULL
        AND preflight_destination_digest IS NULL AND credit_estimate IS NULL)
      OR (admission_version = 1 AND request_source IN ('manual', 'schedule', 'release')
        AND request_idempotency_digest ~ '^[0-9a-f]{64}$'
        AND request_checksum ~ '^[0-9a-f]{64}$'
        AND usage_quota_reservation_id IS NOT NULL AND domain_verification_id IS NOT NULL
        AND preflight_checked_at IS NOT NULL AND preflight_status_code BETWEEN 100 AND 499
        AND preflight_destination_digest ~ '^[0-9a-f]{64}$' AND credit_estimate > 0)
    SQL
  end

  def dispatch_shape
    <<~SQL.squish
      dispatch_attempt_count >= 0
      AND (dispatch_attempt_count = 0 OR dispatch_attempted_at IS NOT NULL)
      AND (dispatch_enqueued_at IS NULL OR
        (dispatch_attempted_at IS NOT NULL AND dispatch_enqueued_at >= dispatch_attempted_at
          AND dispatch_last_error_category IS NULL))
      AND (dispatch_last_error_category IS NULL OR
        dispatch_last_error_category ~ '^[a-z][a-z0-9_]{0,63}$')
    SQL
  end

  def replace_input_guard(include_admission:)
    admission_fields = if include_admission
      <<~SQL
        OR NEW.request_source IS DISTINCT FROM OLD.request_source
        OR NEW.request_idempotency_digest IS DISTINCT FROM OLD.request_idempotency_digest
        OR NEW.request_checksum IS DISTINCT FROM OLD.request_checksum
        OR NEW.admission_version IS DISTINCT FROM OLD.admission_version
        OR NEW.usage_quota_reservation_id IS DISTINCT FROM OLD.usage_quota_reservation_id
        OR NEW.domain_verification_id IS DISTINCT FROM OLD.domain_verification_id
        OR NEW.preflight_checked_at IS DISTINCT FROM OLD.preflight_checked_at
        OR NEW.preflight_status_code IS DISTINCT FROM OLD.preflight_status_code
        OR NEW.preflight_destination_digest IS DISTINCT FROM OLD.preflight_destination_digest
        OR NEW.credit_estimate IS DISTINCT FROM OLD.credit_estimate
      SQL
    else
      ""
    end

    execute <<~SQL
      CREATE OR REPLACE FUNCTION protect_scan_inputs() RETURNS trigger AS $$
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
          OR NEW.requested_at IS DISTINCT FROM OLD.requested_at
          #{admission_fields} THEN
          RAISE EXCEPTION 'scan input and provenance are immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
