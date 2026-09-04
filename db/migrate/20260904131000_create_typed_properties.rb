# frozen_string_literal: true

class CreateTypedProperties < ActiveRecord::Migration[8.1]
  def up
    add_index :authorization_scope_references,
      %i[organization_id id scope_type project_id project_scope_type],
      unique: true,
      name: "index_authorization_scopes_on_property_identity"

    create_properties
    create_website_configs
    create_android_configs
    create_ios_configs
    protect_stable_identity
  end

  def down
    execute "DROP TRIGGER IF EXISTS properties_protect_stable_identity ON properties"
    execute "DROP FUNCTION IF EXISTS protect_property_stable_identity()"
    drop_table :ios_property_configs
    drop_table :android_property_configs
    drop_table :website_property_configs
    drop_table :properties
    remove_index :authorization_scope_references,
      name: "index_authorization_scopes_on_property_identity"
  end

  private

  def create_properties
    create_table :properties, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.citext :display_name, null: false
      t.string :kind, limit: 32, null: false
      t.string :status, limit: 24, null: false, default: "active"
      t.string :verification_status, limit: 24, null: false, default: "unverified"
      t.datetime :verified_at
      t.integer :configuration_version, null: false, default: 1
      t.string :authorization_scope_type, limit: 24, null: false, default: "Property"
      t.string :authorization_project_scope_type, limit: 24, null: false, default: "Project"
      t.datetime :archived_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_foreign_key :properties, :organizations, on_delete: :restrict
    add_foreign_key :properties, :projects,
      column: %i[organization_id project_id],
      primary_key: %i[organization_id id],
      on_delete: :restrict,
      name: "fk_properties_same_org_project"
    add_foreign_key :properties, :authorization_scope_references,
      column: %i[organization_id id authorization_scope_type project_id authorization_project_scope_type],
      primary_key: %i[organization_id id scope_type project_id project_scope_type],
      on_delete: :restrict,
      name: "fk_properties_same_scope_hierarchy"

    add_index :properties, %i[organization_id project_id display_name], unique: true,
      name: "index_properties_on_project_and_display_name"
    add_index :properties, %i[organization_id project_id status display_name id],
      name: "index_properties_on_project_status_name"
    add_index :properties, %i[organization_id project_id id kind configuration_version], unique: true,
      name: "index_properties_on_typed_identity"

    add_check_constraint :properties,
      "kind IN ('website', 'web_application', 'android_app', 'ios_app')",
      name: "properties_kind_allowlist"
    add_check_constraint :properties,
      "char_length(display_name::text) BETWEEN 2 AND 160 AND display_name::text = btrim(display_name::text)",
      name: "properties_display_name_format"
    add_check_constraint :properties,
      "verification_status IN ('unverified', 'pending', 'verified', 'failed', 'expired', 'revoked')",
      name: "properties_verification_status_allowlist"
    add_check_constraint :properties,
      "verification_status <> 'verified' OR verified_at IS NOT NULL",
      name: "properties_verified_timestamp"
    add_check_constraint :properties,
      "configuration_version = 1",
      name: "properties_configuration_version"
    add_check_constraint :properties,
      "authorization_scope_type = 'Property' AND authorization_project_scope_type = 'Project'",
      name: "properties_authorization_scope_types"
    add_check_constraint :properties,
      "(status = 'active' AND archived_at IS NULL) OR (status = 'archived' AND archived_at IS NOT NULL)",
      name: "properties_lifecycle_consistency"
  end

  def create_website_configs
    create_table :website_property_configs, id: false do |t|
      t.uuid :property_id, null: false, primary_key: true
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.string :property_kind, limit: 32, null: false
      t.integer :configuration_version, null: false, default: 1
      t.string :scheme, limit: 8, null: false
      t.citext :host, null: false
      t.integer :port, null: false
      t.text :origin, null: false

      t.timestamps
    end
    add_typed_property_foreign_key(:website_property_configs)
    add_index :website_property_configs, %i[organization_id project_id origin], unique: true,
      name: "index_website_configs_on_normalized_origin"
    add_check_constraint :website_property_configs,
      "property_kind IN ('website', 'web_application') AND configuration_version = 1",
      name: "website_configs_type_and_version"
    add_check_constraint :website_property_configs,
      "scheme IN ('http', 'https') AND port BETWEEN 1 AND 65535",
      name: "website_configs_transport"
    add_check_constraint :website_property_configs,
      "host::text = lower(host::text) AND host::text ~ '^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$'",
      name: "website_configs_host_format"
    add_check_constraint :website_property_configs,
      "char_length(origin) BETWEEN 8 AND 2048 AND origin = " \
        "scheme || '://' || lower(host::text) || CASE WHEN (scheme = 'http' AND port = 80) " \
        "OR (scheme = 'https' AND port = 443) THEN '' ELSE ':' || port::text END",
      name: "website_configs_canonical_origin"
  end

  def create_android_configs
    create_table :android_property_configs, id: false do |t|
      t.uuid :property_id, null: false, primary_key: true
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.string :property_kind, limit: 32, null: false, default: "android_app"
      t.integer :configuration_version, null: false, default: 1
      t.citext :package_name, null: false

      t.timestamps
    end
    add_typed_property_foreign_key(:android_property_configs)
    add_index :android_property_configs, %i[organization_id project_id package_name], unique: true,
      name: "index_android_configs_on_normalized_package"
    add_check_constraint :android_property_configs,
      "property_kind = 'android_app' AND configuration_version = 1",
      name: "android_configs_type_and_version"
    add_check_constraint :android_property_configs,
      "package_name::text = lower(package_name::text) AND " \
        "package_name::text ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'",
      name: "android_configs_package_format"
  end

  def create_ios_configs
    create_table :ios_property_configs, id: false do |t|
      t.uuid :property_id, null: false, primary_key: true
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.string :property_kind, limit: 32, null: false, default: "ios_app"
      t.integer :configuration_version, null: false, default: 1
      t.citext :bundle_id, null: false
      t.string :team_id, limit: 10, null: false

      t.timestamps
    end
    add_typed_property_foreign_key(:ios_property_configs)
    add_index :ios_property_configs, %i[organization_id project_id team_id bundle_id], unique: true,
      name: "index_ios_configs_on_normalized_application"
    add_check_constraint :ios_property_configs,
      "property_kind = 'ios_app' AND configuration_version = 1",
      name: "ios_configs_type_and_version"
    add_check_constraint :ios_property_configs,
      "bundle_id::text = lower(bundle_id::text) AND " \
        "bundle_id::text ~ '^[a-z][a-z0-9-]*(\\.[a-z][a-z0-9-]*)+$'",
      name: "ios_configs_bundle_format"
    add_check_constraint :ios_property_configs,
      "team_id ~ '^[A-Z0-9]{10}$'",
      name: "ios_configs_team_format"
  end

  def add_typed_property_foreign_key(table)
    add_foreign_key table, :properties,
      column: %i[organization_id project_id property_id property_kind configuration_version],
      primary_key: %i[organization_id project_id id kind configuration_version],
      on_delete: :restrict,
      name: "fk_#{table}_typed_property"
  end

  def protect_stable_identity
    execute <<~SQL
      CREATE FUNCTION protect_property_stable_identity() RETURNS trigger AS $$
      BEGIN
        IF NEW.id IS DISTINCT FROM OLD.id
          OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.kind IS DISTINCT FROM OLD.kind
          OR NEW.configuration_version IS DISTINCT FROM OLD.configuration_version
          OR NEW.authorization_scope_type IS DISTINCT FROM OLD.authorization_scope_type
          OR NEW.authorization_project_scope_type IS DISTINCT FROM OLD.authorization_project_scope_type THEN
          RAISE EXCEPTION 'property stable identity cannot be changed';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
    execute <<~SQL
      CREATE TRIGGER properties_protect_stable_identity
      BEFORE UPDATE ON properties
      FOR EACH ROW EXECUTE FUNCTION protect_property_stable_identity();
    SQL
  end
end
