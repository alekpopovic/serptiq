# frozen_string_literal: true

class CreateCrawlPolicies < ActiveRecord::Migration[8.1]
  def up
    create_table :crawl_policy_sets, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.integer :current_version, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :crawl_policy_sets, :property_environments,
      column: %i[organization_id project_id property_id environment_id],
      primary_key: %i[organization_id project_id property_id id],
      on_delete: :restrict, name: "fk_crawl_policy_sets_environment"
    add_index :crawl_policy_sets, %i[organization_id project_id property_id environment_id],
      unique: true, name: "index_crawl_policy_sets_on_environment"
    add_index :crawl_policy_sets,
      %i[id organization_id project_id property_id environment_id], unique: true,
      name: "index_crawl_policy_sets_on_tenant_identity"
    add_check_constraint :crawl_policy_sets, "current_version >= 0",
      name: "crawl_policy_sets_current_version"

    create_table :crawl_policy_versions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :crawl_policy_set_id, null: false
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.integer :version, null: false
      t.text :start_urls, array: true, null: false, default: []
      t.text :sitemap_urls, array: true, null: false, default: []
      t.text :include_patterns, array: true, null: false, default: []
      t.text :exclude_patterns, array: true, null: false, default: []
      t.integer :max_urls, null: false
      t.integer :max_depth, null: false
      t.string :query_handling, limit: 24, null: false
      t.string :user_agent_suffix, limit: 32
      t.decimal :request_rate_per_second, precision: 6, scale: 2, null: false
      t.integer :max_concurrency, null: false
      t.string :robots_behavior, limit: 24, null: false
      t.integer :rendering_sample_percent, null: false
      t.integer :max_rendered_pages, null: false
      t.integer :artifact_retention_days, null: false
      t.uuid :created_by_membership_id, null: false
      t.string :change_kind, limit: 24, null: false
      t.datetime :created_at, null: false
    end

    add_foreign_key :crawl_policy_versions, :crawl_policy_sets,
      column: %i[crawl_policy_set_id organization_id project_id property_id environment_id],
      primary_key: %i[id organization_id project_id property_id environment_id],
      on_delete: :restrict, name: "fk_crawl_policy_versions_policy_set"
    add_foreign_key :crawl_policy_versions, :memberships,
      column: %i[organization_id created_by_membership_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_crawl_policy_versions_tenant_actor"
    add_index :crawl_policy_versions, %i[crawl_policy_set_id version], unique: true,
      name: "index_crawl_policy_versions_on_sequence"
    add_index :crawl_policy_versions,
      %i[organization_id project_id property_id environment_id id], unique: true,
      name: "index_crawl_policy_versions_on_tenant_identity"
    add_index :crawl_policy_versions,
      %i[organization_id project_id property_id environment_id version], unique: true,
      name: "index_crawl_policy_versions_on_environment_version"
    add_check_constraint :crawl_policy_versions, "version > 0",
      name: "crawl_policy_versions_positive_version"
    add_check_constraint :crawl_policy_versions,
      "cardinality(start_urls) BETWEEN 1 AND 20 AND cardinality(sitemap_urls) <= 20 " \
        "AND cardinality(include_patterns) <= 50 AND cardinality(exclude_patterns) <= 50 " \
        "AND octet_length(array_to_string(start_urls, '')) <= 40960 " \
        "AND octet_length(array_to_string(sitemap_urls, '')) <= 40960 " \
        "AND octet_length(array_to_string(include_patterns, '')) <= 12800 " \
        "AND octet_length(array_to_string(exclude_patterns, '')) <= 12800",
      name: "crawl_policy_versions_bounded_lists"
    add_check_constraint :crawl_policy_versions,
      "max_urls BETWEEN 1 AND 1000000 AND max_depth BETWEEN 0 AND 20 " \
        "AND request_rate_per_second BETWEEN 0.10 AND 10.00 " \
        "AND max_concurrency BETWEEN 1 AND 1000",
      name: "crawl_policy_versions_crawl_bounds"
    add_check_constraint :crawl_policy_versions,
      "query_handling IN ('ignore', 'tracking_only', 'all') " \
        "AND robots_behavior = 'respect' AND change_kind IN ('configured', 'reset', 'onboarding')",
      name: "crawl_policy_versions_allowlists"
    add_check_constraint :crawl_policy_versions,
      "user_agent_suffix IS NULL OR user_agent_suffix ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$'",
      name: "crawl_policy_versions_user_agent_suffix"
    add_check_constraint :crawl_policy_versions,
      "rendering_sample_percent BETWEEN 0 AND 100 AND max_rendered_pages >= 0 " \
        "AND ((rendering_sample_percent = 0 AND max_rendered_pages = 0) " \
        "OR (rendering_sample_percent > 0 AND max_rendered_pages > 0))",
      name: "crawl_policy_versions_rendering_shape"
    add_check_constraint :crawl_policy_versions,
      "artifact_retention_days BETWEEN 0 AND 36500",
      name: "crawl_policy_versions_retention"

    create_table :crawl_policy_snapshots, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :scan_id, null: false
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :crawl_policy_version_id, null: false
      t.integer :policy_version, null: false
      t.jsonb :configuration, null: false
      t.string :configuration_digest, limit: 64, null: false
      t.datetime :created_at, null: false
    end

    add_foreign_key :crawl_policy_snapshots, :crawl_policy_versions,
      column: %i[organization_id project_id property_id environment_id crawl_policy_version_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_crawl_policy_snapshots_policy_version"
    add_index :crawl_policy_snapshots, :scan_id, unique: true
    add_index :crawl_policy_snapshots, %i[organization_id scan_id], unique: true,
      name: "index_crawl_policy_snapshots_on_tenant_scan"
    add_check_constraint :crawl_policy_snapshots, "policy_version > 0",
      name: "crawl_policy_snapshots_positive_version"
    add_check_constraint :crawl_policy_snapshots,
      "jsonb_typeof(configuration) = 'object' AND octet_length(configuration::text) <= 32768",
      name: "crawl_policy_snapshots_bounded_configuration"
    add_check_constraint :crawl_policy_snapshots,
      "configuration_digest ~ '^[0-9a-f]{64}$'",
      name: "crawl_policy_snapshots_digest"

    protect_immutable_rows
  end

  def down
    execute "DROP TRIGGER IF EXISTS crawl_policy_snapshots_immutable ON crawl_policy_snapshots"
    execute "DROP TRIGGER IF EXISTS crawl_policy_versions_immutable ON crawl_policy_versions"
    execute "DROP FUNCTION IF EXISTS reject_crawl_policy_immutable_change()"
    drop_table :crawl_policy_snapshots
    drop_table :crawl_policy_versions
    drop_table :crawl_policy_sets
  end

  private

  def protect_immutable_rows
    execute <<~SQL
      CREATE FUNCTION reject_crawl_policy_immutable_change() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION '% rows are immutable', TG_TABLE_NAME;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER crawl_policy_versions_immutable
      BEFORE UPDATE OR DELETE ON crawl_policy_versions
      FOR EACH ROW EXECUTE FUNCTION reject_crawl_policy_immutable_change();

      CREATE TRIGGER crawl_policy_snapshots_immutable
      BEFORE UPDATE OR DELETE ON crawl_policy_snapshots
      FOR EACH ROW EXECUTE FUNCTION reject_crawl_policy_immutable_change();
    SQL
  end
end
