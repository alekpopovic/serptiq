# frozen_string_literal: true

class CreateProjects < ActiveRecord::Migration[8.1]
  def up
    create_table :projects, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.citext :slug, null: false
      t.string :name, limit: 160, null: false
      t.text :description, null: false, default: ""
      t.string :status, limit: 32, null: false, default: "active"
      t.string :default_locale, limit: 16, null: false, default: "en"
      t.string :time_zone, limit: 64, null: false, default: "UTC"
      t.string :external_release_key, limit: 40, null: false
      t.string :authorization_scope_type, limit: 24, null: false, default: "Project"
      t.datetime :archived_at
      t.datetime :deletion_requested_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_foreign_key :projects, :organizations, on_delete: :restrict
    add_foreign_key :projects, :authorization_scope_references,
      column: %i[organization_id id authorization_scope_type],
      primary_key: %i[organization_id id scope_type],
      on_delete: :restrict,
      name: "fk_projects_same_org_authorization_scope"

    add_index :projects, %i[organization_id id], unique: true,
      name: "index_projects_on_organization_and_id"
    add_index :projects, %i[organization_id slug], unique: true,
      name: "index_projects_on_organization_and_slug"
    add_index :projects, :external_release_key, unique: true,
      name: "index_projects_on_external_release_key"
    add_index :projects, %i[organization_id status name id],
      name: "index_projects_on_org_status_name"

    add_check_constraint :projects,
      "slug::text ~ '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$'",
      name: "projects_slug_format"
    add_check_constraint :projects,
      "char_length(name) BETWEEN 2 AND 160 AND name = btrim(name)",
      name: "projects_name_format"
    add_check_constraint :projects,
      "char_length(description) <= 2000",
      name: "projects_description_bounded"
    add_check_constraint :projects,
      "default_locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'",
      name: "projects_locale_format"
    add_check_constraint :projects,
      "char_length(time_zone) BETWEEN 1 AND 64 AND time_zone = btrim(time_zone)",
      name: "projects_time_zone_format"
    add_check_constraint :projects,
      "external_release_key ~ '^prj_[0-9a-f]{32}$'",
      name: "projects_external_release_key_format"
    add_check_constraint :projects,
      "authorization_scope_type = 'Project'",
      name: "projects_authorization_scope_type"
    add_check_constraint :projects, lifecycle_constraint,
      name: "projects_lifecycle_consistency"

    execute <<~SQL
      CREATE FUNCTION protect_project_stable_identity() RETURNS trigger AS $$
      BEGIN
        IF NEW.organization_id <> OLD.organization_id
          OR NEW.slug <> OLD.slug
          OR NEW.external_release_key <> OLD.external_release_key
          OR NEW.authorization_scope_type <> OLD.authorization_scope_type THEN
          RAISE EXCEPTION 'project stable identity cannot be changed';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
    execute <<~SQL
      CREATE TRIGGER projects_protect_stable_identity
      BEFORE UPDATE ON projects
      FOR EACH ROW EXECUTE FUNCTION protect_project_stable_identity();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS projects_protect_stable_identity ON projects"
    execute "DROP FUNCTION IF EXISTS protect_project_stable_identity()"
    drop_table :projects
  end

  private

  def lifecycle_constraint
    <<~SQL.squish
      (status = 'active' AND archived_at IS NULL AND deletion_requested_at IS NULL)
      OR (status = 'archived' AND archived_at IS NOT NULL AND deletion_requested_at IS NULL)
      OR (status = 'pending_deletion' AND archived_at IS NOT NULL AND deletion_requested_at IS NOT NULL
        AND deletion_requested_at >= archived_at)
    SQL
  end
end
