# frozen_string_literal: true

class CreateCrawlSitemapDiscovery < ActiveRecord::Migration[8.1]
  DISCOVERY_STATUSES = %w[running completed partially_completed failed].freeze
  FILE_STATUSES = %w[pending fetched unavailable unreachable oversized malformed rejected].freeze
  FILE_SOURCES = %w[configured robots well_known sitemap_index].freeze
  DOCUMENT_KINDS = %w[urlset sitemap_index].freeze
  ENTRY_KINDS = %w[page sitemap].freeze
  SCOPE_STATUSES = %w[in_scope out_of_scope].freeze
  RELATIONSHIP_STATUSES = %w[
    frontier_inserted frontier_duplicate frontier_limit queued duplicate circular
    depth_rejected document_limit out_of_scope
  ].freeze

  def up
    create_discoveries
    create_files
    create_entries
    protect_records
  end

  def down
    execute "DROP TRIGGER IF EXISTS crawl_sitemap_entries_immutable ON crawl_sitemap_entries"
    execute "DROP FUNCTION IF EXISTS protect_crawl_sitemap_entry()"
    execute "DROP TRIGGER IF EXISTS crawl_sitemap_files_protect ON crawl_sitemap_files"
    execute "DROP FUNCTION IF EXISTS protect_crawl_sitemap_file()"
    execute "DROP TRIGGER IF EXISTS crawl_sitemap_discoveries_protect ON crawl_sitemap_discoveries"
    execute "DROP FUNCTION IF EXISTS protect_crawl_sitemap_discovery()"
    drop_table :crawl_sitemap_entries
    drop_table :crawl_sitemap_files
    drop_table :crawl_sitemap_discoveries
  end

  private

  def create_discoveries
    create_table :crawl_sitemap_discoveries, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :scan_id, null: false
      t.string :status, limit: 32, null: false, default: "running"
      t.bigint :documents_discovered_count, null: false, default: 0
      t.bigint :documents_processed_count, null: false, default: 0
      t.bigint :documents_succeeded_count, null: false, default: 0
      t.bigint :documents_failed_count, null: false, default: 0
      t.bigint :entries_observed_count, null: false, default: 0
      t.bigint :entries_in_scope_count, null: false, default: 0
      t.bigint :entries_out_of_scope_count, null: false, default: 0
      t.bigint :entries_invalid_count, null: false, default: 0
      t.bigint :frontier_inserted_count, null: false, default: 0
      t.bigint :fetch_attempt_count, null: false, default: 0
      t.bigint :metered_fetch_count, null: false, default: 0
      t.bigint :compressed_bytes_count, null: false, default: 0
      t.bigint :decompressed_bytes_count, null: false, default: 0
      t.bigint :warning_count, null: false, default: 0
      t.text :warning_codes, array: true, null: false, default: []
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end

    add_foreign_key :crawl_sitemap_discoveries, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_crawl_sitemap_discoveries_exact_scan"
    add_index :crawl_sitemap_discoveries, :scan_id, unique: true
    add_index :crawl_sitemap_discoveries, %i[scan_id id], unique: true,
      name: "index_crawl_sitemap_discoveries_on_scan_and_id"
    add_index :crawl_sitemap_discoveries, %i[organization_id project_id property_id scan_id],
      name: "index_crawl_sitemap_discoveries_on_tenant_scan"
    add_check_constraint :crawl_sitemap_discoveries,
      "status IN (#{quote_list(DISCOVERY_STATUSES)}) AND " \
        "((status = 'running' AND finished_at IS NULL) OR " \
        "(status <> 'running' AND finished_at IS NOT NULL AND finished_at >= started_at))",
      name: "crawl_sitemap_discoveries_lifecycle"
    add_check_constraint :crawl_sitemap_discoveries, discovery_counter_constraint,
      name: "crawl_sitemap_discoveries_counters"
    add_check_constraint :crawl_sitemap_discoveries,
      "cardinality(warning_codes) <= 1000 AND array_position(warning_codes, NULL) IS NULL " \
        "AND octet_length(array_to_string(warning_codes, '')) <= 64000",
      name: "crawl_sitemap_discoveries_warnings"
  end

  def create_files
    create_table :crawl_sitemap_files, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :scan_id, null: false
      t.uuid :sitemap_discovery_id, null: false
      t.uuid :parent_sitemap_file_id
      t.text :url, null: false
      t.string :url_digest, limit: 64, null: false
      t.string :source, limit: 24, null: false
      t.integer :index_depth, null: false
      t.string :status, limit: 24, null: false, default: "pending"
      t.string :document_kind, limit: 24
      t.text :final_url
      t.integer :http_status
      t.datetime :retrieved_at
      t.string :artifact_sha256, limit: 64
      t.string :content_type, limit: 128
      t.boolean :gzip
      t.bigint :compressed_bytes
      t.bigint :decompressed_bytes
      t.integer :redirect_count
      t.integer :parser_version
      t.bigint :entry_count, null: false, default: 0
      t.bigint :entries_in_scope_count, null: false, default: 0
      t.bigint :entries_out_of_scope_count, null: false, default: 0
      t.bigint :entries_invalid_count, null: false, default: 0
      t.bigint :child_count, null: false, default: 0
      t.integer :warning_count, null: false, default: 0
      t.jsonb :warnings, null: false, default: []
      t.string :error_code, limit: 64
      t.timestamps
    end

    add_foreign_key :crawl_sitemap_files, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_crawl_sitemap_files_exact_scan"
    add_foreign_key :crawl_sitemap_files, :crawl_sitemap_discoveries,
      column: %i[scan_id sitemap_discovery_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_sitemap_files_same_scan_discovery"
    add_index :crawl_sitemap_files, %i[scan_id id], unique: true,
      name: "index_crawl_sitemap_files_on_scan_and_id"
    add_foreign_key :crawl_sitemap_files, :crawl_sitemap_files,
      column: %i[scan_id parent_sitemap_file_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_sitemap_files_same_scan_parent"
    add_index :crawl_sitemap_files, %i[scan_id url_digest], unique: true,
      name: "index_crawl_sitemap_files_on_scan_url"
    add_index :crawl_sitemap_files, %i[sitemap_discovery_id status index_depth created_at],
      name: "index_crawl_sitemap_files_on_discovery_queue"
    add_check_constraint :crawl_sitemap_files,
      "octet_length(url) BETWEEN 1 AND 8192 AND url_digest ~ '^[0-9a-f]{64}$' " \
        "AND (final_url IS NULL OR octet_length(final_url) BETWEEN 1 AND 8192) " \
        "AND (artifact_sha256 IS NULL OR artifact_sha256 ~ '^[0-9a-f]{64}$')",
      name: "crawl_sitemap_files_identity"
    add_check_constraint :crawl_sitemap_files,
      "source IN (#{quote_list(FILE_SOURCES)}) AND index_depth BETWEEN 0 AND 10 " \
        "AND (parent_sitemap_file_id IS NULL OR parent_sitemap_file_id <> id)",
      name: "crawl_sitemap_files_provenance"
    add_check_constraint :crawl_sitemap_files, file_result_constraint,
      name: "crawl_sitemap_files_result"
    add_check_constraint :crawl_sitemap_files,
      "entry_count >= 0 AND entries_in_scope_count >= 0 AND entries_out_of_scope_count >= 0 " \
        "AND entries_invalid_count >= 0 " \
        "AND entry_count = entries_in_scope_count + entries_out_of_scope_count + entries_invalid_count " \
        "AND child_count >= 0 AND warning_count BETWEEN 0 AND 1000 " \
        "AND jsonb_typeof(warnings) = 'array' AND pg_column_size(warnings) <= 131072",
      name: "crawl_sitemap_files_counters"
  end

  def create_entries
    create_table :crawl_sitemap_entries, id: :bigint do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :scan_id, null: false
      t.uuid :sitemap_file_id, null: false
      t.integer :entry_index, null: false
      t.string :entry_kind, limit: 16, null: false
      t.text :location_url, null: false
      t.string :location_digest, limit: 64, null: false
      t.integer :normalization_version, null: false
      t.string :scope_status, limit: 24, null: false
      t.string :scope_reason, limit: 64, null: false
      t.string :relationship_status, limit: 32, null: false
      t.text :lastmod_text
      t.datetime :lastmod_at
      t.string :lastmod_precision, limit: 16
      t.bigint :crawl_url_id
      t.uuid :child_sitemap_file_id
      t.datetime :created_at, null: false
    end

    add_foreign_key :crawl_sitemap_entries, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_crawl_sitemap_entries_exact_scan"
    add_foreign_key :crawl_sitemap_entries, :crawl_sitemap_files,
      column: %i[scan_id sitemap_file_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_sitemap_entries_same_scan_file"
    add_foreign_key :crawl_sitemap_entries, :crawl_sitemap_files,
      column: %i[scan_id child_sitemap_file_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_sitemap_entries_same_scan_child"
    add_foreign_key :crawl_sitemap_entries, :crawl_urls,
      column: %i[scan_id crawl_url_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_sitemap_entries_same_scan_url"
    add_index :crawl_sitemap_entries, %i[sitemap_file_id entry_index], unique: true,
      name: "index_crawl_sitemap_entries_on_file_position"
    add_index :crawl_sitemap_entries, %i[sitemap_file_id entry_kind location_digest], unique: true,
      name: "index_crawl_sitemap_entries_on_file_location"
    add_index :crawl_sitemap_entries, %i[scan_id entry_kind location_digest],
      name: "index_crawl_sitemap_entries_on_scan_location"
    add_index :crawl_sitemap_entries, %i[scan_id scope_status relationship_status],
      name: "index_crawl_sitemap_entries_on_scan_outcome"
    add_check_constraint :crawl_sitemap_entries,
      "entry_index > 0 AND entry_kind IN (#{quote_list(ENTRY_KINDS)}) " \
        "AND octet_length(location_url) BETWEEN 1 AND 8192 " \
        "AND location_digest ~ '^[0-9a-f]{64}$' AND normalization_version > 0",
      name: "crawl_sitemap_entries_identity"
    add_check_constraint :crawl_sitemap_entries, entry_outcome_constraint,
      name: "crawl_sitemap_entries_outcome"
    add_check_constraint :crawl_sitemap_entries,
      "(lastmod_text IS NULL AND lastmod_at IS NULL AND lastmod_precision IS NULL) OR " \
        "(lastmod_text IS NOT NULL AND octet_length(lastmod_text) BETWEEN 1 AND 64 " \
        "AND lastmod_precision IN ('date', 'datetime', 'invalid') " \
        "AND ((lastmod_precision = 'invalid' AND lastmod_at IS NULL) OR " \
        "(lastmod_precision <> 'invalid' AND lastmod_at IS NOT NULL)))",
      name: "crawl_sitemap_entries_lastmod"
  end

  def discovery_counter_constraint
    names = %w[
      documents_discovered_count documents_processed_count documents_succeeded_count
      documents_failed_count entries_observed_count entries_in_scope_count
      entries_out_of_scope_count entries_invalid_count frontier_inserted_count
      fetch_attempt_count metered_fetch_count compressed_bytes_count
      decompressed_bytes_count warning_count
    ]
    nonnegative = names.map { |name| "#{name} >= 0" }.join(" AND ")
    "#{nonnegative} AND documents_processed_count = documents_succeeded_count + documents_failed_count " \
      "AND entries_observed_count = entries_in_scope_count + entries_out_of_scope_count + entries_invalid_count " \
      "AND frontier_inserted_count <= entries_in_scope_count " \
      "AND metered_fetch_count <= fetch_attempt_count"
  end

  def file_result_constraint
    <<~SQL.squish
      status IN (#{quote_list(FILE_STATUSES)})
      AND (document_kind IS NULL OR document_kind IN (#{quote_list(DOCUMENT_KINDS)}))
      AND (http_status IS NULL OR http_status BETWEEN 100 AND 599)
      AND (content_type IS NULL OR octet_length(content_type) BETWEEN 1 AND 128)
      AND (redirect_count IS NULL OR redirect_count BETWEEN 0 AND 5)
      AND (parser_version IS NULL OR parser_version > 0)
      AND (compressed_bytes IS NULL OR compressed_bytes >= 0)
      AND (decompressed_bytes IS NULL OR decompressed_bytes >= 0)
      AND (error_code IS NULL OR error_code ~ '^[a-z][a-z0-9_]{0,63}$')
      AND (status <> 'pending' OR (retrieved_at IS NULL AND artifact_sha256 IS NULL
        AND http_status IS NULL AND final_url IS NULL AND document_kind IS NULL
        AND compressed_bytes IS NULL AND decompressed_bytes IS NULL
        AND redirect_count IS NULL AND parser_version IS NULL AND error_code IS NULL))
      AND (status <> 'fetched' OR (http_status BETWEEN 200 AND 299 AND retrieved_at IS NOT NULL
        AND artifact_sha256 IS NOT NULL AND final_url IS NOT NULL
        AND document_kind IS NOT NULL AND parser_version IS NOT NULL))
      AND (status <> 'rejected' OR (retrieved_at IS NULL AND http_status IS NULL
        AND artifact_sha256 IS NULL AND error_code IS NOT NULL))
    SQL
  end

  def entry_outcome_constraint
    <<~SQL.squish
      scope_status IN (#{quote_list(SCOPE_STATUSES)})
      AND scope_reason ~ '^[a-z][a-z0-9_]{0,63}$'
      AND relationship_status IN (#{quote_list(RELATIONSHIP_STATUSES)})
      AND (scope_status <> 'out_of_scope' OR relationship_status = 'out_of_scope')
      AND (crawl_url_id IS NULL OR entry_kind = 'page')
      AND (child_sitemap_file_id IS NULL OR entry_kind = 'sitemap')
      AND (relationship_status <> 'frontier_inserted' OR crawl_url_id IS NOT NULL)
      AND (relationship_status NOT IN ('queued', 'duplicate', 'circular')
        OR child_sitemap_file_id IS NOT NULL)
    SQL
  end

  def protect_records
    execute <<~SQL
      CREATE FUNCTION protect_crawl_sitemap_discovery() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN RETURN OLD; END IF;
          RAISE EXCEPTION 'sitemap discovery deletion requires an active lifecycle workflow';
        END IF;
        IF OLD.status <> 'running' THEN
          RAISE EXCEPTION 'terminal sitemap discoveries are immutable';
        END IF;
        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
          OR NEW.started_at IS DISTINCT FROM OLD.started_at
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'sitemap discovery identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_sitemap_discoveries_protect
      BEFORE UPDATE OR DELETE ON crawl_sitemap_discoveries
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_sitemap_discovery();

      CREATE FUNCTION protect_crawl_sitemap_file() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN RETURN OLD; END IF;
          RAISE EXCEPTION 'sitemap file deletion requires an active lifecycle workflow';
        END IF;
        IF OLD.status <> 'pending' THEN
          RAISE EXCEPTION 'terminal sitemap files are immutable';
        END IF;
        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
          OR NEW.sitemap_discovery_id IS DISTINCT FROM OLD.sitemap_discovery_id
          OR NEW.parent_sitemap_file_id IS DISTINCT FROM OLD.parent_sitemap_file_id
          OR NEW.url IS DISTINCT FROM OLD.url
          OR NEW.url_digest IS DISTINCT FROM OLD.url_digest
          OR NEW.source IS DISTINCT FROM OLD.source
          OR NEW.index_depth IS DISTINCT FROM OLD.index_depth
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'sitemap file provenance is immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_sitemap_files_protect
      BEFORE UPDATE OR DELETE ON crawl_sitemap_files
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_sitemap_file();

      CREATE FUNCTION protect_crawl_sitemap_entry() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN RETURN OLD; END IF;
        RAISE EXCEPTION 'sitemap entries are immutable';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_sitemap_entries_immutable
      BEFORE UPDATE OR DELETE ON crawl_sitemap_entries
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_sitemap_entry();
    SQL
  end

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
