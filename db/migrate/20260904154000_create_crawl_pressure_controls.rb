# frozen_string_literal: true

class CreateCrawlPressureControls < ActiveRecord::Migration[8.1]
  PRESSURE_SCOPES = %w[global organization scan host].freeze
  PERMIT_STATES = %w[active released expired].freeze
  PERMIT_OUTCOMES = %w[succeeded http_error failed canceled expired].freeze

  def up
    create_control_access_grants
    create_pressure_states
    create_fetch_permits
    add_scan_throttle_observation
    protect_permit_provenance
  end

  def down
    execute "DROP TRIGGER IF EXISTS crawl_fetch_permits_protect_provenance ON crawl_fetch_permits"
    execute "DROP FUNCTION IF EXISTS protect_crawl_fetch_permit_provenance()"
    remove_check_constraint :scans, name: "scans_throttle_observation_shape"
    remove_index :scans, name: "index_scans_on_throttle_observation"
    remove_columns :scans, :throttled_at, :throttle_reason, :throttle_until
    drop_table :crawl_fetch_permits
    drop_table :crawl_pressure_states
    drop_table :crawl_control_access_grants
  end

  private

  def create_control_access_grants
    create_table :crawl_control_access_grants, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :permission, limit: 64, null: false
      t.datetime :granted_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_foreign_key :crawl_control_access_grants, :users, on_delete: :restrict
    add_index :crawl_control_access_grants, %i[user_id permission], unique: true,
      where: "revoked_at IS NULL", name: "index_crawl_control_grants_on_active_permission"
    add_check_constraint :crawl_control_access_grants,
      "permission = 'crawler_control.manage'",
      name: "crawl_control_access_grants_permission"
    add_check_constraint :crawl_control_access_grants,
      "revoked_at IS NULL OR revoked_at >= granted_at",
      name: "crawl_control_access_grants_revocation_time"
  end

  def create_pressure_states
    create_table :crawl_pressure_states, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :scope_type, limit: 24, null: false
      t.string :scope_key_digest, limit: 64, null: false
      t.uuid :organization_id
      t.uuid :project_id
      t.uuid :property_id
      t.uuid :environment_id
      t.uuid :scan_id
      t.string :host_key_digest, limit: 64
      t.datetime :next_fetch_at, null: false
      t.datetime :backoff_until
      t.integer :failure_streak, null: false, default: 0
      t.datetime :disabled_at
      t.uuid :disabled_by_user_id
      t.string :disabled_reason, limit: 64
      t.timestamps
    end

    add_foreign_key :crawl_pressure_states, :organizations, on_delete: :restrict
    add_foreign_key :crawl_pressure_states, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_crawl_pressure_states_exact_scan"
    add_foreign_key :crawl_pressure_states, :users,
      column: :disabled_by_user_id, on_delete: :restrict,
      name: "fk_crawl_pressure_states_disabled_by_user"
    add_index :crawl_pressure_states, %i[scope_type scope_key_digest], unique: true,
      name: "index_crawl_pressure_states_on_scope_key"
    add_index :crawl_pressure_states, %i[organization_id scope_type],
      where: "organization_id IS NOT NULL",
      name: "index_crawl_pressure_states_on_tenant_scope"
    add_index :crawl_pressure_states, %i[backoff_until id],
      where: "backoff_until IS NOT NULL",
      name: "index_crawl_pressure_states_on_backoff"
    add_index :crawl_pressure_states, %i[scope_type disabled_at id],
      where: "disabled_at IS NOT NULL",
      name: "index_crawl_pressure_states_on_disabled"

    add_check_constraint :crawl_pressure_states,
      "scope_type IN (#{quote_list(PRESSURE_SCOPES)}) " \
        "AND scope_key_digest ~ '^[0-9a-f]{64}$' " \
        "AND (host_key_digest IS NULL OR host_key_digest ~ '^[0-9a-f]{64}$')",
      name: "crawl_pressure_states_identity_shape"
    add_check_constraint :crawl_pressure_states, pressure_scope_shape,
      name: "crawl_pressure_states_scope_shape"
    add_check_constraint :crawl_pressure_states,
      "failure_streak BETWEEN 0 AND 20 " \
        "AND (backoff_until IS NULL OR scope_type = 'host')",
      name: "crawl_pressure_states_backoff_shape"
    add_check_constraint :crawl_pressure_states,
      "((disabled_at IS NULL AND disabled_by_user_id IS NULL AND disabled_reason IS NULL) OR " \
        "(scope_type IN ('global', 'host') AND disabled_at IS NOT NULL " \
        "AND disabled_by_user_id IS NOT NULL " \
        "AND disabled_reason ~ '^[a-z][a-z0-9_]{0,63}$'))",
      name: "crawl_pressure_states_emergency_control_shape"
  end

  def create_fetch_permits
    create_table :crawl_fetch_permits, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :scan_id, null: false
      t.bigint :crawl_url_id, null: false
      t.string :host_key_digest, limit: 64, null: false
      t.string :worker_id, limit: 128, null: false
      t.string :permit_token_digest, limit: 64, null: false
      t.string :state, limit: 24, null: false, default: "active"
      t.datetime :acquired_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :released_at
      t.string :release_outcome, limit: 24
      t.string :failure_category, limit: 64
      t.integer :http_status_code
      t.timestamps
    end

    add_foreign_key :crawl_fetch_permits, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_crawl_fetch_permits_exact_scan"
    add_foreign_key :crawl_fetch_permits, :crawl_urls,
      column: %i[scan_id crawl_url_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_fetch_permits_exact_frontier"
    add_index :crawl_fetch_permits, :crawl_url_id, unique: true,
      where: "state = 'active'", name: "index_crawl_fetch_permits_on_active_frontier"
    add_index :crawl_fetch_permits, %i[state expires_at id],
      where: "state = 'active'", name: "index_crawl_fetch_permits_on_active_expiry"
    add_index :crawl_fetch_permits, %i[organization_id state expires_at],
      where: "state = 'active'", name: "index_crawl_fetch_permits_on_active_organization"
    add_index :crawl_fetch_permits, %i[scan_id state expires_at],
      where: "state = 'active'", name: "index_crawl_fetch_permits_on_active_scan"
    add_index :crawl_fetch_permits, %i[host_key_digest state expires_at],
      where: "state = 'active'", name: "index_crawl_fetch_permits_on_active_host"

    add_check_constraint :crawl_fetch_permits,
      "host_key_digest ~ '^[0-9a-f]{64}$' " \
        "AND worker_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$' " \
        "AND permit_token_digest ~ '^[0-9a-f]{64}$'",
      name: "crawl_fetch_permits_identity_shape"
    add_check_constraint :crawl_fetch_permits,
      "state IN (#{quote_list(PERMIT_STATES)}) AND expires_at > acquired_at " \
        "AND ((state = 'active' AND released_at IS NULL AND release_outcome IS NULL " \
        "AND failure_category IS NULL AND http_status_code IS NULL) OR " \
        "(state IN ('released', 'expired') AND released_at IS NOT NULL " \
        "AND released_at >= acquired_at AND release_outcome IN (#{quote_list(PERMIT_OUTCOMES)}) " \
        "AND ((state = 'released' AND release_outcome <> 'expired') " \
        "OR (state = 'expired' AND release_outcome = 'expired'))))",
      name: "crawl_fetch_permits_lifecycle_shape"
    add_check_constraint :crawl_fetch_permits,
      "(failure_category IS NULL OR failure_category ~ '^[a-z][a-z0-9_]{0,63}$') " \
        "AND (http_status_code IS NULL OR http_status_code BETWEEN 100 AND 599) " \
        "AND (state <> 'expired' OR (release_outcome = 'expired' " \
        "AND failure_category = 'permit_expired' AND http_status_code IS NULL))",
      name: "crawl_fetch_permits_result_shape"
  end

  def add_scan_throttle_observation
    add_column :scans, :throttled_at, :datetime
    add_column :scans, :throttle_reason, :string, limit: 64
    add_column :scans, :throttle_until, :datetime
    add_index :scans, %i[throttled_at id], where: "throttled_at IS NOT NULL",
      name: "index_scans_on_throttle_observation"
    add_check_constraint :scans,
      "((throttled_at IS NULL AND throttle_reason IS NULL AND throttle_until IS NULL) OR " \
        "(throttled_at IS NOT NULL AND throttle_reason ~ '^[a-z][a-z0-9_]{0,63}$' " \
        "AND (throttle_until IS NULL OR throttle_until >= throttled_at)))",
      name: "scans_throttle_observation_shape", validate: false
  end

  def pressure_scope_shape
    <<~SQL.squish
      (scope_type = 'global' AND organization_id IS NULL AND project_id IS NULL
        AND property_id IS NULL AND environment_id IS NULL AND scan_id IS NULL
        AND host_key_digest IS NULL)
      OR (scope_type = 'organization' AND organization_id IS NOT NULL AND project_id IS NULL
        AND property_id IS NULL AND environment_id IS NULL AND scan_id IS NULL
        AND host_key_digest IS NULL)
      OR (scope_type = 'scan' AND organization_id IS NOT NULL AND project_id IS NOT NULL
        AND property_id IS NOT NULL AND environment_id IS NOT NULL AND scan_id IS NOT NULL
        AND host_key_digest IS NULL)
      OR (scope_type = 'host' AND organization_id IS NULL AND project_id IS NULL
        AND property_id IS NULL AND environment_id IS NULL AND scan_id IS NULL
        AND host_key_digest IS NOT NULL)
    SQL
  end

  def protect_permit_provenance
    execute <<~SQL
      CREATE FUNCTION protect_crawl_fetch_permit_provenance() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN
            RETURN OLD;
          END IF;
          RAISE EXCEPTION 'crawl fetch permit deletion requires an active lifecycle workflow';
        END IF;

        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
          OR NEW.crawl_url_id IS DISTINCT FROM OLD.crawl_url_id
          OR NEW.host_key_digest IS DISTINCT FROM OLD.host_key_digest
          OR NEW.worker_id IS DISTINCT FROM OLD.worker_id
          OR NEW.permit_token_digest IS DISTINCT FROM OLD.permit_token_digest
          OR NEW.acquired_at IS DISTINCT FROM OLD.acquired_at
          OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'crawl fetch permit provenance is immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_fetch_permits_protect_provenance
      BEFORE UPDATE OR DELETE ON crawl_fetch_permits
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_fetch_permit_provenance();
    SQL
  end

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
