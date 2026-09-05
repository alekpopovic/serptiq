# frozen_string_literal: true

class CreateHtmlExtractionGraph < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  PARSE_STATUSES = %w[parsed malformed unavailable].freeze
  LINK_CLASSIFICATIONS = %w[internal external].freeze
  SCOPE_STATUSES = %w[allowed denied].freeze

  def up
    add_index :crawl_page_snapshots,
      %i[organization_id project_id property_id environment_id scan_id id],
      unique: true, algorithm: :concurrently,
      name: "index_crawl_page_snapshots_on_exact_identity"
    create_page_facts
    create_crawl_links
    protect_rows
  end

  def down
    execute "DROP TRIGGER IF EXISTS crawl_links_immutable ON crawl_links"
    execute "DROP TRIGGER IF EXISTS crawl_page_facts_immutable ON crawl_page_facts"
    execute "DROP FUNCTION IF EXISTS protect_crawl_link_rows()"
    execute "DROP FUNCTION IF EXISTS protect_crawl_page_fact_rows()"
    drop_table :crawl_links
    drop_table :crawl_page_facts
    remove_index :crawl_page_snapshots,
      name: "index_crawl_page_snapshots_on_exact_identity",
      algorithm: :concurrently
  end

  private

  def create_page_facts
    create_table :crawl_page_facts, id: :bigint do |t|
      tenant_identity(t)
      t.bigint :page_snapshot_id, null: false
      t.string :parser_version, limit: 64, null: false
      t.string :content_sha256, limit: 64, null: false
      t.string :fact_digest, limit: 64, null: false
      t.string :parse_status, limit: 24, null: false
      t.integer :parse_error_count, null: false, default: 0
      t.integer :element_count, null: false, default: 0
      t.text :effective_base_url
      t.string :title_status, limit: 24, null: false
      t.text :title_summary
      t.string :title_digest, limit: 64
      t.string :description_status, limit: 24, null: false
      t.text :description_summary
      t.string :description_digest, limit: 64
      t.string :language_status, limit: 24, null: false
      t.string :document_language, limit: 64
      t.jsonb :fact_statuses, null: false, default: {}
      t.jsonb :meta_directives, null: false, default: []
      t.jsonb :headings, null: false, default: []
      t.jsonb :canonicals, null: false, default: []
      t.jsonb :hreflangs, null: false, default: []
      t.jsonb :images, null: false, default: []
      t.jsonb :structured_data_blocks, null: false, default: []
      t.jsonb :counts, null: false, default: {}
      t.timestamps
    end

    add_foreign_key :crawl_page_facts, :crawl_page_snapshots,
      column: exact_snapshot_columns(:page_snapshot_id),
      primary_key: exact_snapshot_columns(:id),
      on_delete: :restrict, name: "fk_crawl_page_facts_exact_snapshot"
    add_index :crawl_page_facts, :page_snapshot_id, unique: true
    add_index :crawl_page_facts, %i[scan_id title_digest],
      where: "title_digest IS NOT NULL",
      name: "index_crawl_page_facts_on_scan_title"
    add_index :crawl_page_facts, %i[organization_id scan_id parse_status id],
      name: "index_crawl_page_facts_on_tenant_scan_status"
    add_check_constraint :crawl_page_facts,
      "parser_version ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$' " \
        "AND content_sha256 ~ '^[0-9a-f]{64}$' AND fact_digest ~ '^[0-9a-f]{64}$' " \
        "AND parse_status IN (#{quote_list(PARSE_STATUSES)}) " \
        "AND parse_error_count BETWEEN 0 AND 20 AND element_count BETWEEN 0 AND 50000 " \
        "AND (effective_base_url IS NULL OR octet_length(effective_base_url) BETWEEN 1 AND 8192)",
      name: "crawl_page_facts_identity_shape"
    add_check_constraint :crawl_page_facts,
      "title_status IN ('present', 'absent', 'malformed', 'unavailable') " \
        "AND description_status IN ('present', 'absent', 'malformed', 'unavailable') " \
        "AND language_status IN ('present', 'absent', 'malformed', 'unavailable') " \
        "AND (title_summary IS NULL OR octet_length(title_summary) <= 2048) " \
        "AND (description_summary IS NULL OR octet_length(description_summary) <= 4096) " \
        "AND (title_digest IS NULL OR title_digest ~ '^[0-9a-f]{64}$') " \
        "AND (description_digest IS NULL OR description_digest ~ '^[0-9a-f]{64}$')",
      name: "crawl_page_facts_scalar_shape"
    add_check_constraint :crawl_page_facts, <<~SQL.squish,
      jsonb_typeof(fact_statuses) = 'object'
      AND jsonb_typeof(meta_directives) = 'array'
      AND jsonb_typeof(headings) = 'array'
      AND jsonb_typeof(canonicals) = 'array'
      AND jsonb_typeof(hreflangs) = 'array'
      AND jsonb_typeof(images) = 'array'
      AND jsonb_typeof(structured_data_blocks) = 'array'
      AND jsonb_typeof(counts) = 'object'
      AND pg_column_size(fact_statuses) <= 4096
      AND pg_column_size(meta_directives) <= 65536
      AND pg_column_size(headings) <= 131072
      AND pg_column_size(canonicals) <= 32768
      AND pg_column_size(hreflangs) <= 65536
      AND pg_column_size(images) <= 262144
      AND pg_column_size(structured_data_blocks) <= 262144
      AND pg_column_size(counts) <= 4096
      AND pg_column_size(fact_statuses) + pg_column_size(meta_directives)
        + pg_column_size(headings) + pg_column_size(canonicals)
        + pg_column_size(hreflangs) + pg_column_size(images)
        + pg_column_size(structured_data_blocks) + pg_column_size(counts) <= 786432
    SQL
      name: "crawl_page_facts_bounded_json"
    add_check_constraint :crawl_page_facts, <<~SQL.squish,
      (parse_status = 'unavailable'
        AND title_status = 'unavailable'
        AND description_status = 'unavailable'
        AND language_status = 'unavailable')
      OR parse_status IN ('parsed', 'malformed')
    SQL
      name: "crawl_page_facts_availability_shape"
  end

  def create_crawl_links
    create_table :crawl_links, id: :bigint do |t|
      tenant_identity(t)
      t.bigint :page_snapshot_id, null: false
      t.bigint :source_crawl_url_id, null: false
      t.bigint :destination_crawl_url_id
      t.text :destination_url, null: false
      t.string :destination_url_digest, limit: 64, null: false
      t.integer :normalization_version, null: false
      t.string :destination_host_digest, limit: 64, null: false
      t.string :classification, limit: 16, null: false
      t.string :scope_status, limit: 16, null: false
      t.string :scope_reason, limit: 64, null: false
      t.string :discovery_status, limit: 24, null: false
      t.string :source_locator, limit: 512, null: false
      t.string :rel_tokens, array: true, null: false, default: []
      t.text :anchor_summary
      t.string :anchor_digest, limit: 64, null: false
      t.boolean :nofollow, null: false, default: false
      t.integer :occurrence_count, null: false, default: 1
      t.integer :nofollow_count, null: false, default: 0
      t.string :edge_digest, limit: 64, null: false
      t.datetime :discovered_at, null: false
      t.timestamps
    end

    add_foreign_key :crawl_links, :crawl_page_snapshots,
      column: exact_snapshot_columns(:page_snapshot_id),
      primary_key: exact_snapshot_columns(:id),
      on_delete: :restrict, name: "fk_crawl_links_exact_snapshot"
    add_foreign_key :crawl_links, :crawl_urls,
      column: %i[scan_id source_crawl_url_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_links_same_scan_source"
    add_foreign_key :crawl_links, :crawl_urls,
      column: %i[scan_id destination_crawl_url_id], primary_key: %i[scan_id id],
      on_delete: :restrict, name: "fk_crawl_links_same_scan_destination"
    add_index :crawl_links, %i[page_snapshot_id destination_url_digest], unique: true,
      name: "index_crawl_links_on_snapshot_destination"
    add_index :crawl_links, %i[scan_id source_crawl_url_id id],
      name: "index_crawl_links_on_scan_source"
    add_index :crawl_links, %i[scan_id destination_crawl_url_id source_crawl_url_id],
      where: "classification = 'internal' AND destination_crawl_url_id IS NOT NULL",
      name: "index_crawl_links_on_internal_destination"
    add_index :crawl_links, %i[organization_id scan_id classification id],
      name: "index_crawl_links_on_tenant_scan_classification"
    add_check_constraint :crawl_links,
      "octet_length(destination_url) BETWEEN 1 AND 8192 " \
        "AND destination_url_digest ~ '^[0-9a-f]{64}$' " \
        "AND destination_host_digest ~ '^[0-9a-f]{64}$' " \
        "AND edge_digest ~ '^[0-9a-f]{64}$' AND anchor_digest ~ '^[0-9a-f]{64}$' " \
        "AND normalization_version BETWEEN 1 AND 100 " \
        "AND classification IN (#{quote_list(LINK_CLASSIFICATIONS)}) " \
        "AND scope_status IN (#{quote_list(SCOPE_STATUSES)}) " \
        "AND scope_reason ~ '^[a-z][a-z0-9_]{0,63}$'",
      name: "crawl_links_identity_shape"
    add_check_constraint :crawl_links,
      "octet_length(source_locator) BETWEEN 1 AND 512 " \
        "AND (anchor_summary IS NULL OR octet_length(anchor_summary) <= 2048) " \
        "AND cardinality(rel_tokens) <= 20 " \
        "AND pg_column_size(rel_tokens) <= 2048 AND array_position(rel_tokens, NULL) IS NULL " \
        "AND array_to_string(rel_tokens, ',') ~ '^([a-z][a-z0-9_-]{0,63})(,[a-z][a-z0-9_-]{0,63})*$|^$' " \
        "AND occurrence_count BETWEEN 1 AND 5000 " \
        "AND nofollow_count BETWEEN 0 AND occurrence_count " \
        "AND nofollow = (nofollow_count > 0)",
      name: "crawl_links_evidence_shape"
    add_check_constraint :crawl_links, <<~SQL.squish,
      (classification = 'external' AND destination_crawl_url_id IS NULL
        AND scope_status = 'denied' AND discovery_status = 'not_applicable')
      OR (classification = 'internal'
        AND ((scope_status = 'allowed' AND destination_crawl_url_id IS NOT NULL
            AND discovery_status = 'linked')
          OR (scope_status = 'allowed' AND destination_crawl_url_id IS NULL
            AND discovery_status = 'not_admitted')
          OR (scope_status = 'denied' AND destination_crawl_url_id IS NULL
            AND discovery_status = 'not_applicable')))
    SQL
      name: "crawl_links_destination_shape"
  end

  def protect_rows
    execute <<~SQL
      CREATE FUNCTION protect_crawl_page_fact_rows() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN RETURN OLD; END IF;
        RAISE EXCEPTION 'crawl page facts are immutable outside an active lifecycle workflow';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_page_facts_immutable
      BEFORE UPDATE OR DELETE ON crawl_page_facts
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_page_fact_rows();

      CREATE FUNCTION protect_crawl_link_rows() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN RETURN OLD; END IF;
        RAISE EXCEPTION 'crawl links are immutable outside an active lifecycle workflow';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_links_immutable
      BEFORE UPDATE OR DELETE ON crawl_links
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_link_rows();
    SQL
  end

  def tenant_identity(table)
    table.uuid :organization_id, null: false
    table.uuid :project_id, null: false
    table.uuid :property_id, null: false
    table.uuid :environment_id, null: false
    table.uuid :scan_id, null: false
  end

  def exact_snapshot_columns(id_column)
    %i[organization_id project_id property_id environment_id scan_id] + [ id_column ]
  end

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
