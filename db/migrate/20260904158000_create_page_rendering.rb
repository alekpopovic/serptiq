# frozen_string_literal: true

class CreatePageRendering < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  STATES = %w[pending processing completed failed canceled skipped].freeze

  def up
    add_index :crawl_page_facts,
      %i[organization_id project_id property_id environment_id scan_id id],
      unique: true, algorithm: :concurrently,
      name: "index_crawl_page_facts_on_exact_identity"
    create_renders
    create_rendered_facts
    create_rendered_links
    protect_rows
  end

  def down
    execute "DROP TRIGGER IF EXISTS crawl_rendered_links_immutable ON crawl_rendered_links"
    execute "DROP TRIGGER IF EXISTS crawl_rendered_page_facts_immutable ON crawl_rendered_page_facts"
    execute "DROP TRIGGER IF EXISTS crawl_page_renders_protect_rows ON crawl_page_renders"
    execute "DROP FUNCTION IF EXISTS protect_crawl_rendered_link_rows()"
    execute "DROP FUNCTION IF EXISTS protect_crawl_rendered_page_fact_rows()"
    execute "DROP FUNCTION IF EXISTS protect_crawl_page_render_rows()"
    drop_table :crawl_rendered_links
    drop_table :crawl_rendered_page_facts
    drop_table :crawl_page_renders
    remove_index :crawl_page_facts,
      name: "index_crawl_page_facts_on_exact_identity",
      algorithm: :concurrently
  end

  private

  def create_renders
    create_table :crawl_page_renders, id: :bigint do |t|
      tenant_identity(t)
      t.bigint :page_snapshot_id, null: false
      t.bigint :page_fact_id, null: false
      t.string :state, limit: 24, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.integer :maximum_attempts, null: false, default: 3
      t.string :worker_id, limit: 128
      t.string :lease_token_digest, limit: 64
      t.datetime :started_at
      t.datetime :lease_expires_at
      t.datetime :next_attempt_at
      t.datetime :finished_at
      t.string :failure_category, limit: 64
      t.boolean :screenshot_enabled, null: false, default: false
      t.text :requested_url, null: false
      t.string :requested_url_digest, limit: 64, null: false
      t.text :final_url
      t.string :final_url_digest, limit: 64
      t.uuid :rendered_dom_artifact_id
      t.uuid :screenshot_artifact_id
      t.string :rendered_dom_sha256, limit: 64
      t.string :renderer_version, limit: 64
      t.string :ferrum_version, limit: 64
      t.string :browser_product, limit: 128
      t.string :browser_revision, limit: 128
      t.string :protocol_version, limit: 64
      t.integer :duration_ms
      t.integer :request_count
      t.bigint :response_bytes
      t.jsonb :console_messages, null: false, default: []
      t.jsonb :page_errors, null: false, default: []
      t.jsonb :network_summary, null: false, default: {}
      t.timestamps
    end

    exact_scan_foreign_key(:crawl_page_renders, "fk_crawl_page_renders_exact_scan")
    add_foreign_key :crawl_page_renders, :crawl_page_snapshots,
      column: exact_columns(:page_snapshot_id), primary_key: exact_columns(:id),
      on_delete: :restrict, name: "fk_crawl_page_renders_exact_snapshot"
    add_foreign_key :crawl_page_renders, :crawl_page_facts,
      column: exact_columns(:page_fact_id), primary_key: exact_columns(:id),
      on_delete: :restrict, name: "fk_crawl_page_renders_exact_source_fact"
    add_foreign_key :crawl_page_renders, :artifacts,
      column: exact_columns(:rendered_dom_artifact_id), primary_key: exact_columns(:id),
      on_delete: :restrict, name: "fk_crawl_page_renders_exact_dom_artifact"
    add_foreign_key :crawl_page_renders, :artifacts,
      column: exact_columns(:screenshot_artifact_id), primary_key: exact_columns(:id),
      on_delete: :restrict, name: "fk_crawl_page_renders_exact_screenshot_artifact"
    add_index :crawl_page_renders, :page_snapshot_id, unique: true
    add_index :crawl_page_renders, exact_columns(:id), unique: true,
      name: "index_crawl_page_renders_on_exact_identity"
    add_index :crawl_page_renders, %i[state next_attempt_at id],
      where: "state = 'pending'", name: "index_crawl_page_renders_on_pending"
    add_index :crawl_page_renders, %i[state lease_expires_at id],
      where: "state = 'processing'", name: "index_crawl_page_renders_on_recovery"
    add_index :crawl_page_renders, %i[organization_id scan_id state id],
      name: "index_crawl_page_renders_on_tenant_scan_state"

    add_check_constraint :crawl_page_renders,
      "state IN (#{quote_list(STATES)}) AND attempts BETWEEN 0 AND maximum_attempts " \
        "AND maximum_attempts BETWEEN 1 AND 10 " \
        "AND octet_length(requested_url) BETWEEN 1 AND 8192 " \
        "AND requested_url_digest ~ '^[0-9a-f]{64}$' " \
        "AND (failure_category IS NULL OR failure_category ~ '^[a-z][a-z0-9_]{0,63}$')",
      name: "crawl_page_renders_identity_shape"
    add_check_constraint :crawl_page_renders, <<~SQL.squish,
      (state = 'pending' AND worker_id IS NULL AND lease_token_digest IS NULL
        AND started_at IS NULL AND lease_expires_at IS NULL
        AND next_attempt_at IS NOT NULL AND finished_at IS NULL)
      OR (state = 'processing' AND worker_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'
        AND lease_token_digest ~ '^[0-9a-f]{64}$' AND started_at IS NOT NULL
        AND lease_expires_at > started_at AND next_attempt_at IS NULL AND finished_at IS NULL)
      OR (state IN ('completed', 'failed', 'canceled', 'skipped')
        AND worker_id IS NULL AND lease_token_digest IS NULL AND started_at IS NULL
        AND lease_expires_at IS NULL AND next_attempt_at IS NULL AND finished_at IS NOT NULL)
    SQL
      name: "crawl_page_renders_lifecycle_shape"
    add_check_constraint :crawl_page_renders, <<~SQL.squish,
      (state = 'completed'
        AND final_url IS NOT NULL AND octet_length(final_url) BETWEEN 1 AND 8192
        AND final_url_digest ~ '^[0-9a-f]{64}$'
        AND rendered_dom_artifact_id IS NOT NULL
        AND rendered_dom_sha256 ~ '^[0-9a-f]{64}$'
        AND renderer_version ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'
        AND ferrum_version ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'
        AND browser_product IS NOT NULL AND octet_length(browser_product) BETWEEN 1 AND 128
        AND browser_revision IS NOT NULL AND octet_length(browser_revision) BETWEEN 1 AND 128
        AND protocol_version ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'
        AND duration_ms BETWEEN 0 AND 300000 AND request_count BETWEEN 1 AND 5000
        AND response_bytes BETWEEN 0 AND 524288000
        AND ((screenshot_enabled AND screenshot_artifact_id IS NOT NULL)
          OR (NOT screenshot_enabled AND screenshot_artifact_id IS NULL)))
      OR (state <> 'completed' AND final_url IS NULL AND final_url_digest IS NULL
        AND rendered_dom_artifact_id IS NULL AND screenshot_artifact_id IS NULL
        AND rendered_dom_sha256 IS NULL AND renderer_version IS NULL AND ferrum_version IS NULL
        AND browser_product IS NULL AND browser_revision IS NULL AND protocol_version IS NULL
        AND duration_ms IS NULL AND request_count IS NULL AND response_bytes IS NULL)
    SQL
      name: "crawl_page_renders_result_shape"
    add_check_constraint :crawl_page_renders, <<~SQL.squish,
      jsonb_typeof(console_messages) = 'array' AND jsonb_array_length(console_messages) <= 100
      AND jsonb_typeof(page_errors) = 'array' AND jsonb_array_length(page_errors) <= 100
      AND jsonb_typeof(network_summary) = 'object'
      AND pg_column_size(console_messages) <= 32768 AND pg_column_size(page_errors) <= 32768
      AND pg_column_size(network_summary) <= 65536
    SQL
      name: "crawl_page_renders_bounded_json"
  end

  def create_rendered_facts
    create_table :crawl_rendered_page_facts, id: :bigint do |t|
      tenant_identity(t)
      t.bigint :page_render_id, null: false
      t.string :parser_version, limit: 64, null: false
      t.string :content_sha256, limit: 64, null: false
      t.string :fact_digest, limit: 64, null: false
      t.string :parse_status, limit: 24, null: false
      t.jsonb :facts, null: false, default: {}
      t.timestamps
    end

    add_foreign_key :crawl_rendered_page_facts, :crawl_page_renders,
      column: exact_columns(:page_render_id), primary_key: exact_columns(:id),
      on_delete: :restrict, name: "fk_crawl_rendered_facts_exact_render"
    add_index :crawl_rendered_page_facts, :page_render_id, unique: true
    add_index :crawl_rendered_page_facts, %i[organization_id scan_id parse_status id],
      name: "index_crawl_rendered_facts_on_tenant_scan_status"
    add_check_constraint :crawl_rendered_page_facts,
      "parser_version ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$' " \
        "AND content_sha256 ~ '^[0-9a-f]{64}$' AND fact_digest ~ '^[0-9a-f]{64}$' " \
        "AND parse_status IN ('parsed', 'malformed') AND jsonb_typeof(facts) = 'object' " \
        "AND pg_column_size(facts) <= 786432",
      name: "crawl_rendered_page_facts_shape"
  end

  def create_rendered_links
    create_table :crawl_rendered_links, id: :bigint do |t|
      tenant_identity(t)
      t.bigint :page_render_id, null: false
      t.text :destination_url, null: false
      t.string :destination_url_digest, limit: 64, null: false
      t.string :destination_host_digest, limit: 64, null: false
      t.integer :normalization_version, null: false
      t.string :classification, limit: 16, null: false
      t.string :scope_status, limit: 16, null: false
      t.string :scope_reason, limit: 64, null: false
      t.string :source_locator, limit: 512, null: false
      t.string :rel_tokens, array: true, null: false, default: []
      t.text :anchor_summary
      t.string :anchor_digest, limit: 64, null: false
      t.integer :occurrence_count, null: false
      t.integer :nofollow_count, null: false
      t.string :edge_digest, limit: 64, null: false
      t.timestamps
    end

    add_foreign_key :crawl_rendered_links, :crawl_page_renders,
      column: exact_columns(:page_render_id), primary_key: exact_columns(:id),
      on_delete: :restrict, name: "fk_crawl_rendered_links_exact_render"
    add_index :crawl_rendered_links, %i[page_render_id destination_url_digest], unique: true,
      name: "index_crawl_rendered_links_on_render_destination"
    add_index :crawl_rendered_links, %i[organization_id scan_id classification id],
      name: "index_crawl_rendered_links_on_tenant_scan_classification"
    add_check_constraint :crawl_rendered_links, <<~SQL.squish,
      octet_length(destination_url) BETWEEN 1 AND 8192
      AND destination_url_digest ~ '^[0-9a-f]{64}$' AND destination_host_digest ~ '^[0-9a-f]{64}$'
      AND edge_digest ~ '^[0-9a-f]{64}$' AND anchor_digest ~ '^[0-9a-f]{64}$'
      AND normalization_version BETWEEN 1 AND 100
      AND classification IN ('internal', 'external') AND scope_status IN ('allowed', 'denied')
      AND scope_reason ~ '^[a-z][a-z0-9_]{0,63}$'
      AND octet_length(source_locator) BETWEEN 1 AND 512
      AND (anchor_summary IS NULL OR octet_length(anchor_summary) <= 2048)
      AND cardinality(rel_tokens) <= 20 AND pg_column_size(rel_tokens) <= 2048
      AND array_position(rel_tokens, NULL) IS NULL
      AND occurrence_count BETWEEN 1 AND 5000 AND nofollow_count BETWEEN 0 AND occurrence_count
    SQL
      name: "crawl_rendered_links_shape"
  end

  def protect_rows
    execute <<~SQL
      CREATE FUNCTION protect_crawl_page_render_rows() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN RETURN OLD; END IF;
          RAISE EXCEPTION 'crawl page render deletion requires an active lifecycle workflow';
        END IF;
        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
          OR NEW.page_snapshot_id IS DISTINCT FROM OLD.page_snapshot_id
          OR NEW.page_fact_id IS DISTINCT FROM OLD.page_fact_id
          OR NEW.requested_url IS DISTINCT FROM OLD.requested_url
          OR NEW.requested_url_digest IS DISTINCT FROM OLD.requested_url_digest
          OR NEW.screenshot_enabled IS DISTINCT FROM OLD.screenshot_enabled
          OR NEW.maximum_attempts IS DISTINCT FROM OLD.maximum_attempts
          OR OLD.state IN ('completed', 'failed', 'canceled', 'skipped')
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'crawl page render identity or terminal result is immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_page_renders_protect_rows
      BEFORE UPDATE OR DELETE ON crawl_page_renders
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_page_render_rows();

      CREATE FUNCTION protect_crawl_rendered_page_fact_rows() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN RETURN OLD; END IF;
        RAISE EXCEPTION 'crawl rendered page facts are immutable outside an active lifecycle workflow';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_rendered_page_facts_immutable
      BEFORE UPDATE OR DELETE ON crawl_rendered_page_facts
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_rendered_page_fact_rows();

      CREATE FUNCTION protect_crawl_rendered_link_rows() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN RETURN OLD; END IF;
        RAISE EXCEPTION 'crawl rendered links are immutable outside an active lifecycle workflow';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_rendered_links_immutable
      BEFORE UPDATE OR DELETE ON crawl_rendered_links
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_rendered_link_rows();
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

  def exact_columns(id_column)
    %i[organization_id project_id property_id environment_id scan_id] + [ id_column ]
  end

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
