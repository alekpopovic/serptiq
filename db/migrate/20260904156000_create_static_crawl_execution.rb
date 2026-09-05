# frozen_string_literal: true

class CreateStaticCrawlExecution < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  EXECUTION_STATES = %w[pending initializing ready completed partially_completed canceled failed].freeze
  FETCH_OUTCOMES = %w[succeeded http_error rejected failed canceled throttled].freeze
  SNIFFED_KINDS = %w[empty html xml json pdf image text binary unknown].freeze
  SNAPSHOT_STATES = %w[pending processing completed failed skipped].freeze

  def up
    create_executions
    create_fetch_results
    create_page_snapshots
    add_result_foreign_key
    protect_rows
  end

  def down
    execute "DROP TRIGGER IF EXISTS crawl_page_snapshots_protect_identity ON crawl_page_snapshots"
    execute "DROP TRIGGER IF EXISTS crawl_fetch_results_protect_rows ON crawl_fetch_results"
    execute "DROP TRIGGER IF EXISTS crawl_scan_executions_protect_identity ON crawl_scan_executions"
    execute "DROP FUNCTION IF EXISTS protect_crawl_page_snapshot_identity()"
    execute "DROP FUNCTION IF EXISTS protect_crawl_fetch_result_rows()"
    execute "DROP FUNCTION IF EXISTS protect_crawl_scan_execution_identity()"
    remove_foreign_key :crawl_urls, name: "fk_crawl_urls_same_scan_fetch_result"
    drop_table :crawl_page_snapshots
    drop_table :crawl_fetch_results
    drop_table :crawl_scan_executions
    remove_index :artifacts, name: "index_artifacts_on_exact_scan_identity",
      algorithm: :concurrently
  end

  private

  def create_executions
    create_table :crawl_scan_executions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      tenant_identity(t)
      t.string :state, limit: 32, null: false, default: "pending"
      t.integer :initialization_attempts, null: false, default: 0
      t.integer :maximum_initialization_attempts, null: false, default: 3
      t.string :initialization_worker_id, limit: 128
      t.string :initialization_token_digest, limit: 64
      t.datetime :initialization_started_at
      t.datetime :initialization_lease_expires_at
      t.datetime :initialized_at
      t.string :last_failure_category, limit: 64
      t.datetime :last_live_update_at
      t.datetime :finished_at
      t.timestamps
    end

    exact_scan_foreign_key(:crawl_scan_executions, "fk_crawl_scan_executions_exact_scan")
    add_index :crawl_scan_executions, :scan_id, unique: true
    add_index :crawl_scan_executions,
      %i[state initialization_lease_expires_at id],
      name: "index_crawl_scan_executions_on_recovery"
    add_check_constraint :crawl_scan_executions,
      "state IN (#{quote_list(EXECUTION_STATES)}) " \
        "AND initialization_attempts BETWEEN 0 AND maximum_initialization_attempts " \
        "AND maximum_initialization_attempts BETWEEN 1 AND 10 " \
        "AND (last_failure_category IS NULL OR last_failure_category ~ '^[a-z][a-z0-9_]{0,63}$')",
      name: "crawl_scan_executions_state_shape"
    add_check_constraint :crawl_scan_executions, <<~SQL.squish,
      ((state = 'initializing') =
        (initialization_worker_id IS NOT NULL
          AND initialization_worker_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'
          AND initialization_token_digest ~ '^[0-9a-f]{64}$'
          AND initialization_started_at IS NOT NULL
          AND initialization_lease_expires_at > initialization_started_at))
      AND (state NOT IN ('ready', 'completed', 'partially_completed')
        OR initialized_at IS NOT NULL)
      AND (state NOT IN ('completed', 'partially_completed', 'canceled', 'failed')
        OR finished_at IS NOT NULL)
    SQL
      name: "crawl_scan_executions_lifecycle_shape"
  end

  def create_fetch_results
    create_table :crawl_fetch_results, id: :bigint do |t|
      tenant_identity(t)
      t.bigint :crawl_url_id, null: false
      t.uuid :artifact_id
      t.integer :attempt_number, null: false
      t.string :source_key_digest, limit: 64, null: false
      t.string :lease_token_digest, limit: 64, null: false
      t.string :request_method, limit: 8, null: false, default: "GET"
      t.string :outcome, limit: 24, null: false
      t.string :failure_category, limit: 64
      t.integer :http_status_code
      t.text :final_url, null: false
      t.string :final_url_digest, limit: 64, null: false
      t.string :media_type, limit: 128
      t.string :charset, limit: 64
      t.string :content_encoding, limit: 64, null: false
      t.jsonb :response_headers, null: false, default: {}
      t.bigint :header_bytes, null: false, default: 0
      t.bigint :compressed_bytes, null: false, default: 0
      t.bigint :decoded_bytes, null: false, default: 0
      t.string :body_sha256, limit: 64, null: false
      t.string :sniffed_kind, limit: 24, null: false
      t.integer :request_count, null: false
      t.integer :retry_count, null: false
      t.integer :redirect_count, null: false
      t.integer :duration_ms, null: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end

    exact_scan_foreign_key(:crawl_fetch_results, "fk_crawl_fetch_results_exact_scan")
    add_foreign_key :crawl_fetch_results, :crawl_urls,
      column: %i[scan_id crawl_url_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_fetch_results_same_scan_url"
    add_index :crawl_fetch_results, %i[scan_id id], unique: true,
      name: "index_crawl_fetch_results_on_scan_and_id"
    add_index :crawl_fetch_results, %i[scan_id crawl_url_id attempt_number], unique: true,
      name: "index_crawl_fetch_results_on_url_attempt"
    add_index :crawl_fetch_results, %i[scan_id source_key_digest], unique: true,
      name: "index_crawl_fetch_results_on_source"
    add_index :crawl_fetch_results, %i[organization_id scan_id outcome id],
      name: "index_crawl_fetch_results_on_tenant_scan_outcome"
    add_check_constraint :crawl_fetch_results,
      "attempt_number BETWEEN 1 AND 10 AND source_key_digest ~ '^[0-9a-f]{64}$' " \
        "AND lease_token_digest ~ '^[0-9a-f]{64}$' AND request_method IN ('GET', 'HEAD') " \
        "AND outcome IN (#{quote_list(FETCH_OUTCOMES)}) " \
        "AND (failure_category IS NULL OR failure_category ~ '^[a-z][a-z0-9_]{0,63}$') " \
        "AND (http_status_code IS NULL OR http_status_code BETWEEN 100 AND 599) " \
        "AND ((outcome = 'succeeded' AND failure_category IS NULL " \
          "AND http_status_code BETWEEN 200 AND 299) " \
        "OR (outcome = 'http_error' AND http_status_code IS NOT NULL " \
          "AND http_status_code NOT BETWEEN 200 AND 299 " \
          "AND failure_category = 'http_' || http_status_code::text) " \
        "OR (outcome IN ('rejected', 'failed', 'canceled', 'throttled') " \
          "AND failure_category IS NOT NULL))",
      name: "crawl_fetch_results_outcome_shape"
    add_check_constraint :crawl_fetch_results,
      "octet_length(final_url) BETWEEN 1 AND 8192 AND final_url_digest ~ '^[0-9a-f]{64}$' " \
        "AND body_sha256 ~ '^[0-9a-f]{64}$' " \
        "AND (media_type IS NULL OR media_type ~ '^[a-z0-9!#\\$&^_.+-]+/[a-z0-9!#\\$&^_.+-]+$') " \
        "AND (charset IS NULL OR charset ~ '^[a-z0-9!#\\$&^_.+\\-]{1,64}$') " \
        "AND content_encoding ~ '^[a-z0-9!#\\$&^_.+\\-]{1,64}$'",
      name: "crawl_fetch_results_metadata_shape"
    add_check_constraint :crawl_fetch_results,
      "jsonb_typeof(response_headers) = 'object' AND pg_column_size(response_headers) <= 16384 " \
        "AND header_bytes BETWEEN 0 AND 262144 " \
        "AND compressed_bytes BETWEEN 0 AND 104857600 " \
        "AND decoded_bytes BETWEEN 0 AND 524288000 " \
        "AND request_count BETWEEN 0 AND 32 AND retry_count BETWEEN 0 AND 10 " \
        "AND redirect_count BETWEEN 0 AND 20 AND duration_ms BETWEEN 0 AND 600000 " \
        "AND retry_count <= request_count AND redirect_count <= request_count " \
        "AND sniffed_kind IN (#{quote_list(SNIFFED_KINDS)})",
      name: "crawl_fetch_results_bounded_shape"

    add_index :artifacts,
      %i[organization_id project_id property_id environment_id scan_id id],
      unique: true, algorithm: :concurrently,
      name: "index_artifacts_on_exact_scan_identity"
    add_foreign_key :crawl_fetch_results, :artifacts,
      column: %i[organization_id project_id property_id environment_id scan_id artifact_id],
      primary_key: %i[organization_id project_id property_id environment_id scan_id id],
      on_delete: :restrict, name: "fk_crawl_fetch_results_exact_artifact"
  end

  def create_page_snapshots
    create_table :crawl_page_snapshots, id: :bigint do |t|
      tenant_identity(t)
      t.bigint :crawl_url_id, null: false
      t.bigint :crawl_fetch_result_id, null: false
      t.uuid :artifact_id, null: false
      t.string :state, limit: 24, null: false, default: "pending"
      t.integer :extraction_attempts, null: false, default: 0
      t.integer :maximum_extraction_attempts, null: false, default: 3
      t.string :extraction_worker_id, limit: 128
      t.string :extraction_token_digest, limit: 64
      t.datetime :extraction_started_at
      t.datetime :extraction_lease_expires_at
      t.datetime :next_attempt_at
      t.string :last_failure_category, limit: 64
      t.integer :discovered_links_count, null: false, default: 0
      t.string :discovery_parser_version, limit: 64
      t.datetime :finished_at
      t.timestamps
    end

    exact_scan_foreign_key(:crawl_page_snapshots, "fk_crawl_page_snapshots_exact_scan")
    add_foreign_key :crawl_page_snapshots, :crawl_urls,
      column: %i[scan_id crawl_url_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_page_snapshots_same_scan_url"
    add_foreign_key :crawl_page_snapshots, :crawl_fetch_results,
      column: %i[scan_id crawl_fetch_result_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_page_snapshots_same_scan_fetch"
    add_foreign_key :crawl_page_snapshots, :artifacts,
      column: %i[organization_id project_id property_id environment_id scan_id artifact_id],
      primary_key: %i[organization_id project_id property_id environment_id scan_id id],
      on_delete: :restrict, name: "fk_crawl_page_snapshots_exact_artifact"
    add_index :crawl_page_snapshots, %i[scan_id crawl_url_id], unique: true,
      name: "index_crawl_page_snapshots_on_scan_url"
    add_index :crawl_page_snapshots, %i[scan_id crawl_fetch_result_id], unique: true,
      name: "index_crawl_page_snapshots_on_scan_fetch"
    add_index :crawl_page_snapshots, %i[state next_attempt_at id],
      name: "index_crawl_page_snapshots_on_work_queue"
    add_index :crawl_page_snapshots, %i[state extraction_lease_expires_at id],
      name: "index_crawl_page_snapshots_on_recovery"
    add_check_constraint :crawl_page_snapshots,
      "state IN (#{quote_list(SNAPSHOT_STATES)}) " \
        "AND extraction_attempts BETWEEN 0 AND maximum_extraction_attempts " \
        "AND maximum_extraction_attempts BETWEEN 1 AND 10 " \
        "AND discovered_links_count BETWEEN 0 AND 100000 " \
        "AND (last_failure_category IS NULL OR last_failure_category ~ '^[a-z][a-z0-9_]{0,63}$') " \
        "AND (discovery_parser_version IS NULL OR discovery_parser_version ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$')",
      name: "crawl_page_snapshots_state_shape"
    add_check_constraint :crawl_page_snapshots, <<~SQL.squish,
      (state = 'pending' AND extraction_worker_id IS NULL AND extraction_token_digest IS NULL
        AND extraction_started_at IS NULL AND extraction_lease_expires_at IS NULL
        AND next_attempt_at IS NOT NULL AND finished_at IS NULL)
      OR (state = 'processing'
        AND extraction_worker_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'
        AND extraction_token_digest ~ '^[0-9a-f]{64}$'
        AND extraction_started_at IS NOT NULL
        AND extraction_lease_expires_at > extraction_started_at
        AND next_attempt_at IS NULL AND finished_at IS NULL)
      OR (state IN ('completed', 'failed', 'skipped')
        AND extraction_worker_id IS NULL AND extraction_token_digest IS NULL
        AND extraction_started_at IS NULL AND extraction_lease_expires_at IS NULL
        AND next_attempt_at IS NULL AND finished_at IS NOT NULL)
    SQL
      name: "crawl_page_snapshots_lifecycle_shape"
  end

  def add_result_foreign_key
    add_foreign_key :crawl_urls, :crawl_fetch_results,
      column: %i[scan_id fetch_result_id], primary_key: %i[scan_id id],
      deferrable: :deferred,
      name: "fk_crawl_urls_same_scan_fetch_result"
  end

  def protect_rows
    execute <<~SQL
      CREATE FUNCTION protect_crawl_scan_execution_identity() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN RETURN OLD; END IF;
          RAISE EXCEPTION 'crawl execution deletion requires an active lifecycle workflow';
        END IF;
        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
          OR NEW.maximum_initialization_attempts IS DISTINCT FROM OLD.maximum_initialization_attempts
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'crawl execution identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_scan_executions_protect_identity
      BEFORE UPDATE OR DELETE ON crawl_scan_executions
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_scan_execution_identity();

      CREATE FUNCTION protect_crawl_fetch_result_rows() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN RETURN OLD; END IF;
        RAISE EXCEPTION 'crawl fetch results are immutable outside an active lifecycle workflow';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_fetch_results_protect_rows
      BEFORE UPDATE OR DELETE ON crawl_fetch_results
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_fetch_result_rows();

      CREATE FUNCTION protect_crawl_page_snapshot_identity() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN RETURN OLD; END IF;
          RAISE EXCEPTION 'crawl page snapshot deletion requires an active lifecycle workflow';
        END IF;
        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
          OR NEW.crawl_url_id IS DISTINCT FROM OLD.crawl_url_id
          OR NEW.crawl_fetch_result_id IS DISTINCT FROM OLD.crawl_fetch_result_id
          OR NEW.artifact_id IS DISTINCT FROM OLD.artifact_id
          OR NEW.maximum_extraction_attempts IS DISTINCT FROM OLD.maximum_extraction_attempts
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'crawl page snapshot identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_page_snapshots_protect_identity
      BEFORE UPDATE OR DELETE ON crawl_page_snapshots
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_page_snapshot_identity();
    SQL
  end

  def tenant_identity(table)
    table.uuid :organization_id, null: false
    table.uuid :project_id, null: false
    table.uuid :property_id, null: false
    table.uuid :environment_id, null: false
    table.uuid :scan_id, null: false
  end

  def exact_scan_foreign_key(table, name)
    add_foreign_key table, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: name
  end

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
