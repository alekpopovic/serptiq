# frozen_string_literal: true

class CreateCrawlFrontier < ActiveRecord::Migration[8.1]
  STATES = %w[pending leased succeeded rejected failed exhausted].freeze
  DISCOVERY_SOURCES = %w[seed sitemap link redirect canonical].freeze
  LEASE_OUTCOMES = %w[retry stale_recovered succeeded rejected failed exhausted].freeze

  def up
    create_table :crawl_urls, id: :bigint do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :scan_id, null: false
      t.string :normalized_url_digest, limit: 64, null: false
      t.integer :normalization_version, null: false
      t.text :normalized_url, null: false
      t.string :host_digest, limit: 64, null: false
      t.integer :depth, null: false
      t.integer :priority, null: false, default: 0
      t.string :discovery_source, limit: 24, null: false
      t.bigint :discovered_from_id
      t.string :state, limit: 24, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.integer :maximum_attempts, null: false
      t.string :leased_by, limit: 128
      t.string :lease_token_digest, limit: 64
      t.datetime :leased_at
      t.datetime :lease_expires_at
      t.datetime :next_attempt_at
      t.string :last_lease_token_digest, limit: 64
      t.string :last_lease_outcome, limit: 24
      t.string :last_failure_category, limit: 64
      t.bigint :fetch_result_id
      t.integer :http_status_code
      t.datetime :completed_at
      t.timestamps
    end

    add_foreign_key :crawl_urls, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_crawl_urls_exact_scan"
    add_index :crawl_urls, %i[scan_id id], unique: true,
      name: "index_crawl_urls_on_scan_and_id"
    add_foreign_key :crawl_urls, :crawl_urls,
      column: %i[scan_id discovered_from_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_urls_same_scan_discovery"
    add_index :crawl_urls, %i[scan_id normalized_url_digest], unique: true,
      name: "index_crawl_urls_on_scan_url_identity"
    add_index :crawl_urls, %i[organization_id project_id scan_id state id],
      name: "index_crawl_urls_on_tenant_scan_state"
    add_index :crawl_urls, %i[next_attempt_at priority depth id],
      order: { priority: :desc }, where: "state = 'pending'",
      include: %i[organization_id scan_id host_digest],
      name: "index_crawl_urls_on_pending_eligibility"
    add_index :crawl_urls, %i[organization_id host_digest next_attempt_at priority depth id],
      order: { priority: :desc }, where: "state = 'pending'",
      include: :scan_id, name: "index_crawl_urls_on_pending_fairness"
    add_index :crawl_urls, %i[lease_expires_at id], where: "state = 'leased'",
      include: %i[organization_id scan_id], name: "index_crawl_urls_on_stale_leases"

    add_check_constraint :crawl_urls,
      "normalization_version > 0 AND normalized_url_digest ~ '^[0-9a-f]{64}$' " \
        "AND host_digest ~ '^[0-9a-f]{64}$' AND octet_length(normalized_url) BETWEEN 1 AND 8192",
      name: "crawl_urls_normalized_identity_shape"
    add_check_constraint :crawl_urls,
      "depth BETWEEN 0 AND 100 AND priority BETWEEN -1000000 AND 1000000 " \
        "AND discovery_source IN (#{quote_list(DISCOVERY_SOURCES)}) " \
        "AND (discovered_from_id IS NULL OR discovered_from_id <> id)",
      name: "crawl_urls_discovery_shape"
    add_check_constraint :crawl_urls,
      "state IN (#{quote_list(STATES)}) AND attempts BETWEEN 0 AND maximum_attempts " \
        "AND maximum_attempts BETWEEN 1 AND 10 AND (state <> 'pending' OR attempts < maximum_attempts)",
      name: "crawl_urls_attempt_shape"
    add_check_constraint :crawl_urls, lifecycle_shape,
      name: "crawl_urls_lifecycle_shape"
    add_check_constraint :crawl_urls,
      "((last_lease_token_digest IS NULL AND last_lease_outcome IS NULL) OR " \
        "(last_lease_token_digest ~ '^[0-9a-f]{64}$' " \
        "AND last_lease_outcome IN (#{quote_list(LEASE_OUTCOMES)}))) " \
        "AND (last_failure_category IS NULL OR last_failure_category ~ '^[a-z][a-z0-9_]{0,63}$')",
      name: "crawl_urls_last_outcome_shape"
    add_check_constraint :crawl_urls,
      "((fetch_result_id IS NULL AND http_status_code IS NULL) OR " \
        "(fetch_result_id > 0 AND (http_status_code IS NULL OR http_status_code BETWEEN 100 AND 599))) " \
        "AND (state <> 'succeeded' OR fetch_result_id IS NOT NULL)",
      name: "crawl_urls_result_shape"

    protect_frontier
  end

  def down
    execute "DROP TRIGGER IF EXISTS crawl_urls_protect_identity ON crawl_urls"
    execute "DROP FUNCTION IF EXISTS protect_crawl_url_identity()"
    drop_table :crawl_urls
  end

  private

  def lifecycle_shape
    <<~SQL.squish
      (state = 'pending' AND leased_by IS NULL AND lease_token_digest IS NULL
        AND leased_at IS NULL AND lease_expires_at IS NULL AND completed_at IS NULL
        AND next_attempt_at IS NOT NULL)
      OR (state = 'leased' AND leased_by ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'
        AND lease_token_digest ~ '^[0-9a-f]{64}$' AND leased_at IS NOT NULL
        AND lease_expires_at > leased_at AND completed_at IS NULL AND next_attempt_at IS NULL)
      OR (state IN ('succeeded', 'rejected', 'failed', 'exhausted')
        AND leased_by IS NULL AND lease_token_digest IS NULL AND leased_at IS NULL
        AND lease_expires_at IS NULL AND next_attempt_at IS NULL AND completed_at IS NOT NULL
        AND last_lease_token_digest IS NOT NULL AND last_lease_outcome = state)
    SQL
  end

  def protect_frontier
    execute <<~SQL
      CREATE FUNCTION protect_crawl_url_identity() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN
            RETURN OLD;
          END IF;
          RAISE EXCEPTION 'crawl URL deletion requires an active lifecycle workflow';
        END IF;

        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
          OR NEW.normalized_url_digest IS DISTINCT FROM OLD.normalized_url_digest
          OR NEW.normalization_version IS DISTINCT FROM OLD.normalization_version
          OR NEW.normalized_url IS DISTINCT FROM OLD.normalized_url
          OR NEW.host_digest IS DISTINCT FROM OLD.host_digest
          OR NEW.discovery_source IS DISTINCT FROM OLD.discovery_source
          OR NEW.discovered_from_id IS DISTINCT FROM OLD.discovered_from_id
          OR NEW.maximum_attempts IS DISTINCT FROM OLD.maximum_attempts
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'crawl URL identity and discovery provenance are immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_urls_protect_identity
      BEFORE UPDATE OR DELETE ON crawl_urls
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_url_identity();
    SQL
  end

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
