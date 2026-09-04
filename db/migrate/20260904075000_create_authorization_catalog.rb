# frozen_string_literal: true

class CreateAuthorizationCatalog < ActiveRecord::Migration[8.1]
  SYSTEM_ROLE_KEYS = %w[owner organization_admin billing_admin seo_lead developer content_editor analyst viewer].freeze

  def change
    create_table :permissions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, limit: 128, null: false
      t.string :category, limit: 64, null: false
      t.string :scope, limit: 32, null: false
      t.string :risk_level, limit: 16, null: false
      t.text :description, null: false
      t.boolean :active, null: false, default: true
      t.string :catalog_checksum, limit: 64, null: false

      t.timestamps
    end
    add_index :permissions, :key, unique: true
    add_check_constraint :permissions,
      "key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'",
      name: "permissions_key_format"
    add_check_constraint :permissions,
      "char_length(category) BETWEEN 2 AND 64 AND category = btrim(category)",
      name: "permissions_category_format"
    add_check_constraint :permissions,
      "char_length(description) BETWEEN 1 AND 500 AND description = btrim(description)",
      name: "permissions_description_format"
    add_check_constraint :permissions, "scope IN ('organization', 'project')",
      name: "permissions_scope_allowlist"
    add_check_constraint :permissions, "risk_level IN ('low', 'medium', 'high', 'critical')",
      name: "permissions_risk_allowlist"
    add_check_constraint :permissions, "catalog_checksum ~ '^[0-9a-f]{64}$'",
      name: "permissions_catalog_checksum_format"

    create_table :roles, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :organization, type: :uuid, null: true, foreign_key: { on_delete: :restrict }
      t.string :key, limit: 64, null: false
      t.string :name, limit: 80, null: false
      t.boolean :system, null: false, default: false
      t.boolean :mutable, null: false, default: true
      t.string :assignable_scopes, array: true, null: false, default: []
      t.string :catalog_checksum, limit: 64
      t.datetime :archived_at

      t.timestamps
    end
    add_index :roles, :key, unique: true, where: "system = TRUE", name: "index_roles_on_system_key"
    add_index :roles, %i[organization_id key], unique: true, where: "system = FALSE",
      name: "index_roles_on_organization_and_key"
    add_index :roles, %i[organization_id id], unique: true, name: "index_roles_on_organization_and_id"
    add_check_constraint :roles, "key ~ '^[a-z][a-z0-9_]{1,63}$'", name: "roles_key_format"
    add_check_constraint :roles,
      "char_length(name) BETWEEN 2 AND 80 AND name = btrim(name)", name: "roles_name_format"
    add_check_constraint :roles, role_ownership_constraint, name: "roles_ownership_consistency"
    add_check_constraint :roles, assignable_scopes_constraint, name: "roles_assignable_scopes_allowlist"

    create_table :role_permissions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :role, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
      t.references :permission, type: :uuid, null: false, foreign_key: { on_delete: :restrict }

      t.timestamps
    end
    add_index :role_permissions, %i[role_id permission_id], unique: true

    create_table :authorization_catalog_revisions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.integer :schema_version, null: false
      t.string :checksum, limit: 64, null: false
      t.string :source_path, limit: 255, null: false
      t.integer :permission_count, null: false
      t.integer :role_count, null: false
      t.datetime :synced_at, null: false

      t.timestamps
    end
    add_index :authorization_catalog_revisions, :checksum, unique: true
    add_check_constraint :authorization_catalog_revisions, "schema_version > 0",
      name: "authorization_catalog_revisions_positive_schema"
    add_check_constraint :authorization_catalog_revisions, "checksum ~ '^[0-9a-f]{64}$'",
      name: "authorization_catalog_revisions_checksum_format"
    add_check_constraint :authorization_catalog_revisions,
      "permission_count > 0 AND role_count > 0",
      name: "authorization_catalog_revisions_positive_counts"
    add_check_constraint :authorization_catalog_revisions,
      "source_path = 'config_blueprints/permissions.yml'",
      name: "authorization_catalog_revisions_source_path"
  end

  private

  def role_ownership_constraint
    keys = SYSTEM_ROLE_KEYS.map { |key| connection.quote(key) }.join(", ")
    <<~SQL.squish
      (system = TRUE AND organization_id IS NULL AND mutable = FALSE AND archived_at IS NULL
        AND catalog_checksum ~ '^[0-9a-f]{64}$' AND key IN (#{keys}))
      OR (system = FALSE AND organization_id IS NOT NULL AND mutable = TRUE
        AND catalog_checksum IS NULL AND key NOT IN (#{keys}))
    SQL
  end

  def assignable_scopes_constraint
    <<~SQL.squish
      assignable_scopes = ARRAY['organization']::varchar[]
      OR assignable_scopes = ARRAY['project']::varchar[]
      OR assignable_scopes = ARRAY['organization', 'project']::varchar[]
    SQL
  end
end
