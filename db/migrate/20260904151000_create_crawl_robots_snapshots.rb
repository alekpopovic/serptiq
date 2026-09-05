# frozen_string_literal: true

class CreateCrawlRobotsSnapshots < ActiveRecord::Migration[8.1]
  RETRIEVAL_STATUSES = %w[fetched unavailable unreachable oversized malformed].freeze

  def up
    create_table :crawl_robots_snapshots, id: :uuid do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :scan_id, null: false
      t.text :origin, null: false
      t.string :origin_digest, limit: 64, null: false
      t.text :source_url, null: false
      t.text :final_url
      t.string :retrieval_status, limit: 24, null: false
      t.integer :http_status
      t.datetime :retrieved_at, null: false
      t.string :artifact_sha256, limit: 64
      t.integer :parser_version, null: false
      t.integer :redirect_count, null: false, default: 0
      t.string :error_code, limit: 64
      t.jsonb :groups, null: false, default: []
      t.text :sitemap_urls, array: true, null: false, default: []
      t.jsonb :warnings, null: false, default: []
      t.boolean :malformed, null: false, default: false
      t.datetime :created_at, null: false
    end

    add_foreign_key :crawl_robots_snapshots, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict,
      name: "fk_crawl_robots_snapshots_exact_scan"
    add_index :crawl_robots_snapshots, %i[scan_id origin_digest], unique: true,
      name: "index_crawl_robots_snapshots_on_scan_origin"
    add_index :crawl_robots_snapshots, %i[organization_id project_id property_id scan_id],
      name: "index_crawl_robots_snapshots_on_tenant_scan"

    add_check_constraint :crawl_robots_snapshots,
      "octet_length(origin) BETWEEN 1 AND 2048 " \
        "AND octet_length(source_url) BETWEEN 1 AND 2048 " \
        "AND (final_url IS NULL OR octet_length(final_url) BETWEEN 1 AND 2048) " \
        "AND origin_digest ~ '^[0-9a-f]{64}$' " \
        "AND (artifact_sha256 IS NULL OR artifact_sha256 ~ '^[0-9a-f]{64}$')",
      name: "crawl_robots_snapshots_identity_shape"
    add_check_constraint :crawl_robots_snapshots,
      "retrieval_status IN (#{quote_list(RETRIEVAL_STATUSES)}) " \
        "AND parser_version > 0 AND redirect_count BETWEEN 0 AND 5 " \
        "AND (http_status IS NULL OR http_status BETWEEN 100 AND 599) " \
        "AND (error_code IS NULL OR error_code ~ '^[a-z][a-z0-9_]{0,63}$')",
      name: "crawl_robots_snapshots_result_shape"
    add_check_constraint :crawl_robots_snapshots,
      "(retrieval_status <> 'fetched' OR " \
        "(http_status BETWEEN 200 AND 299 AND artifact_sha256 IS NOT NULL AND final_url IS NOT NULL)) " \
        "AND (retrieval_status <> 'unavailable' OR http_status BETWEEN 400 AND 499)",
      name: "crawl_robots_snapshots_http_shape"
    add_check_constraint :crawl_robots_snapshots,
      "jsonb_typeof(groups) = 'array' AND pg_column_size(groups) <= 1048576 " \
        "AND jsonb_typeof(warnings) = 'array' AND pg_column_size(warnings) <= 1048576 " \
        "AND cardinality(sitemap_urls) <= 100 " \
        "AND array_position(sitemap_urls, NULL) IS NULL " \
        "AND octet_length(array_to_string(sitemap_urls, '')) <= 204800",
      name: "crawl_robots_snapshots_payload_shape"

    protect_snapshots
    replace_policy_allowlist(robots_values: %w[respect verified_owner_override])
  end

  def down
    replace_policy_allowlist(robots_values: [ "respect" ])
    execute "DROP TRIGGER IF EXISTS crawl_robots_snapshots_immutable ON crawl_robots_snapshots"
    execute "DROP FUNCTION IF EXISTS protect_crawl_robots_snapshot()"
    drop_table :crawl_robots_snapshots
  end

  private

  def protect_snapshots
    execute <<~SQL
      CREATE FUNCTION protect_crawl_robots_snapshot() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN
          RETURN OLD;
        END IF;
        RAISE EXCEPTION 'crawl robots snapshots are immutable';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_robots_snapshots_immutable
      BEFORE UPDATE OR DELETE ON crawl_robots_snapshots
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_robots_snapshot();
    SQL
  end

  def replace_policy_allowlist(robots_values:)
    remove_check_constraint :crawl_policy_versions, name: "crawl_policy_versions_allowlists"
    add_check_constraint :crawl_policy_versions,
      "query_handling IN ('ignore', 'tracking_only', 'all') " \
        "AND robots_behavior IN (#{quote_list(robots_values)}) " \
        "AND change_kind IN ('configured', 'reset', 'onboarding')",
      name: "crawl_policy_versions_allowlists"
  end

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
