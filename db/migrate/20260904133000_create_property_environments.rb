# frozen_string_literal: true

class CreatePropertyEnvironments < ActiveRecord::Migration[8.1]
  def up
    create_table :property_environments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.string :property_kind, limit: 32, null: false
      t.integer :configuration_version, null: false, default: 1
      t.citext :key, null: false
      t.string :kind, limit: 24, null: false
      t.citext :display_name, null: false
      t.boolean :primary, null: false, default: false
      t.string :status, limit: 24, null: false, default: "active"
      t.string :scheme, limit: 8, null: false
      t.citext :host, null: false
      t.integer :port, null: false
      t.text :origin, null: false
      t.datetime :archived_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :property_environments, :properties,
      column: %i[organization_id project_id property_id property_kind configuration_version],
      primary_key: %i[organization_id project_id id kind configuration_version],
      on_delete: :restrict,
      name: "fk_property_environments_typed_property"
    add_index :property_environments, %i[organization_id project_id property_id key], unique: true,
      name: "index_property_environments_on_stable_key"
    add_index :property_environments, %i[organization_id project_id origin], unique: true,
      name: "index_property_environments_on_origin"
    add_index :property_environments, %i[organization_id project_id property_id],
      unique: true,
      where: "\"primary\" = TRUE AND status = 'active' AND kind = 'production'",
      name: "index_property_environments_on_primary_production"
    add_index :property_environments,
      %i[organization_id project_id property_id status kind display_name id],
      name: "index_property_environments_on_directory"

    add_check_constraint :property_environments,
      "property_kind IN ('website', 'web_application') AND configuration_version = 1",
      name: "property_environments_property_type"
    add_check_constraint :property_environments,
      "key::text ~ '^[a-z][a-z0-9-]{1,62}$' AND key::text = lower(key::text)",
      name: "property_environments_key_format"
    add_check_constraint :property_environments,
      "kind IN ('production', 'staging', 'development', 'custom')",
      name: "property_environments_kind_allowlist"
    add_check_constraint :property_environments,
      "char_length(display_name::text) BETWEEN 2 AND 120 AND display_name::text = btrim(display_name::text)",
      name: "property_environments_display_name_format"
    add_check_constraint :property_environments,
      "(status = 'active' AND archived_at IS NULL) OR " \
        "(status = 'archived' AND archived_at IS NOT NULL)",
      name: "property_environments_lifecycle"
    add_check_constraint :property_environments,
      "\"primary\" = FALSE OR (kind = 'production' AND status = 'active')",
      name: "property_environments_primary_shape"
    add_check_constraint :property_environments,
      "scheme IN ('http', 'https') AND port BETWEEN 1 AND 65535",
      name: "property_environments_transport"
    add_check_constraint :property_environments,
      "host::text = lower(host::text) AND " \
        "host::text ~ '^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$'",
      name: "property_environments_host_format"
    add_check_constraint :property_environments,
      "char_length(origin) BETWEEN 8 AND 2048 AND origin = " \
        "scheme || '://' || lower(host::text) || CASE WHEN (scheme = 'http' AND port = 80) " \
        "OR (scheme = 'https' AND port = 443) THEN '' ELSE ':' || port::text END",
      name: "property_environments_canonical_origin"

    backfill_primary_environments
    protect_stable_identity
    enforce_primary_environment
  end

  def down
    execute "DROP TRIGGER IF EXISTS properties_require_primary_environment ON properties"
    execute "DROP TRIGGER IF EXISTS property_environments_require_primary ON property_environments"
    execute "DROP FUNCTION IF EXISTS enforce_property_primary_environment()"
    execute "DROP TRIGGER IF EXISTS property_environments_protect_stable_identity ON property_environments"
    execute "DROP FUNCTION IF EXISTS protect_property_environment_stable_identity()"
    drop_table :property_environments
  end

  private

  def backfill_primary_environments
    execute <<~SQL
      INSERT INTO property_environments (
        id, organization_id, project_id, property_id, property_kind, configuration_version,
        key, kind, display_name, "primary", status, scheme, host, port, origin,
        created_at, updated_at
      )
      SELECT gen_random_uuid(), config.organization_id, config.project_id, config.property_id,
        config.property_kind, config.configuration_version, 'production', 'production', 'Production',
        TRUE, 'active', config.scheme, lower(config.host::text), config.port, config.origin,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM website_property_configs config
    SQL
  end

  def protect_stable_identity
    execute <<~SQL
      CREATE FUNCTION protect_property_environment_stable_identity() RETURNS trigger AS $$
      BEGIN
        IF NEW.id IS DISTINCT FROM OLD.id
          OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.property_kind IS DISTINCT FROM OLD.property_kind
          OR NEW.configuration_version IS DISTINCT FROM OLD.configuration_version
          OR NEW.key IS DISTINCT FROM OLD.key
          OR NEW.kind IS DISTINCT FROM OLD.kind THEN
          RAISE EXCEPTION 'property environment stable identity cannot be changed';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER property_environments_protect_stable_identity
      BEFORE UPDATE ON property_environments
      FOR EACH ROW EXECUTE FUNCTION protect_property_environment_stable_identity();
    SQL
  end

  def enforce_primary_environment
    execute <<~SQL
      CREATE FUNCTION enforce_property_primary_environment() RETURNS trigger AS $$
      DECLARE
        target_property_id uuid;
        target_organization_id uuid;
        target_project_id uuid;
        property_row properties%ROWTYPE;
        primary_count integer;
      BEGIN
        IF TG_TABLE_NAME = 'properties' THEN
          target_property_id := COALESCE(NEW.id, OLD.id);
          target_organization_id := COALESCE(NEW.organization_id, OLD.organization_id);
          target_project_id := COALESCE(NEW.project_id, OLD.project_id);
        ELSE
          target_property_id := COALESCE(NEW.property_id, OLD.property_id);
          target_organization_id := COALESCE(NEW.organization_id, OLD.organization_id);
          target_project_id := COALESCE(NEW.project_id, OLD.project_id);
        END IF;

        SELECT * INTO property_row FROM properties
        WHERE id = target_property_id
          AND organization_id = target_organization_id
          AND project_id = target_project_id;
        IF NOT FOUND OR property_row.status <> 'active'
          OR property_row.kind NOT IN ('website', 'web_application') THEN
          RETURN COALESCE(NEW, OLD);
        END IF;

        SELECT count(*) INTO primary_count FROM property_environments
        WHERE property_id = target_property_id
          AND organization_id = target_organization_id
          AND project_id = target_project_id
          AND "primary" = TRUE AND status = 'active' AND kind = 'production';
        IF primary_count <> 1 THEN
          RAISE EXCEPTION 'active website property requires exactly one primary production environment';
        END IF;
        RETURN COALESCE(NEW, OLD);
      END;
      $$ LANGUAGE plpgsql;

      CREATE CONSTRAINT TRIGGER properties_require_primary_environment
      AFTER INSERT OR UPDATE ON properties DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION enforce_property_primary_environment();

      CREATE CONSTRAINT TRIGGER property_environments_require_primary
      AFTER INSERT OR UPDATE OR DELETE ON property_environments DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION enforce_property_primary_environment();
    SQL
  end
end
