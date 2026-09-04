# frozen_string_literal: true

class CreateOrganizationTenancyFoundation < ActiveRecord::Migration[8.1]
  def up
    create_table :organizations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, limit: 160, null: false
      t.citext :slug, null: false
      t.string :status, limit: 32, null: false, default: "active"
      t.string :default_locale, limit: 16, null: false, default: "en"
      t.string :time_zone, limit: 64, null: false, default: "UTC"
      t.string :data_region, limit: 32, null: false, default: "global"
      t.uuid :current_ownership_id, null: false
      t.datetime :suspended_at
      t.datetime :deletion_requested_at
      t.datetime :deleted_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :organizations, :slug,
      unique: true,
      where: "deleted_at IS NULL",
      name: "index_organizations_on_active_slug"
    add_check_constraint :organizations,
      "slug::text ~ '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$'",
      name: "organizations_slug_format"
    add_check_constraint :organizations,
      "char_length(name) BETWEEN 2 AND 160 AND name = btrim(name)",
      name: "organizations_name_format"
    add_check_constraint :organizations,
      "status IN ('active', 'suspended', 'pending_deletion', 'deleted')",
      name: "organizations_status_allowlist"
    add_check_constraint :organizations,
      "default_locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'",
      name: "organizations_locale_format"
    add_check_constraint :organizations,
      "data_region ~ '^[a-z][a-z0-9_-]{1,31}$'",
      name: "organizations_data_region_format"
    add_check_constraint :organizations,
      organization_lifecycle_constraint,
      name: "organizations_lifecycle_consistency"

    create_table :memberships, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
      t.uuid :user_id, null: false
      t.string :status, limit: 32, null: false, default: "active"
      t.datetime :joined_at, null: false
      t.datetime :suspended_at
      t.datetime :left_at
      t.datetime :last_accessed_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_foreign_key :memberships, :users, column: :user_id, on_delete: :restrict
    add_index :memberships, %i[organization_id user_id], unique: true
    add_index :memberships, %i[user_id status organization_id], name: "index_memberships_on_user_status_and_org"
    add_index :memberships, %i[organization_id id], unique: true,
      name: "index_memberships_on_organization_and_id"
    add_check_constraint :memberships,
      "status IN ('active', 'suspended', 'left')",
      name: "memberships_status_allowlist"
    add_check_constraint :memberships,
      membership_lifecycle_constraint,
      name: "memberships_lifecycle_consistency"

    create_table :organization_ownerships, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
      t.uuid :membership_id, null: false
      t.datetime :assigned_at, null: false
      t.datetime :ended_at

      t.timestamps
    end

    add_foreign_key :organization_ownerships, :memberships,
      column: %i[organization_id membership_id],
      primary_key: %i[organization_id id],
      on_delete: :restrict,
      name: "fk_ownerships_same_organization_membership"
    add_foreign_key :organizations, :organization_ownerships,
      column: :current_ownership_id,
      on_delete: :restrict,
      deferrable: :deferred
    add_index :organization_ownerships, :organization_id,
      unique: true,
      where: "ended_at IS NULL",
      name: "index_organization_ownerships_on_active_org"
    add_index :organization_ownerships, :membership_id,
      where: "ended_at IS NULL",
      name: "index_organization_ownerships_on_active_membership"
    add_check_constraint :organization_ownerships,
      "ended_at IS NULL OR ended_at >= assigned_at",
      name: "organization_ownerships_timestamp_order"
  end

  def down
    if foreign_key_exists?(:organizations, column: :current_ownership_id)
      remove_foreign_key :organizations, column: :current_ownership_id
    end
    drop_table :organization_ownerships
    drop_table :memberships
    drop_table :organizations
  end

  private

  def organization_lifecycle_constraint
    <<~SQL.squish
      (status = 'active' AND suspended_at IS NULL AND deletion_requested_at IS NULL AND deleted_at IS NULL)
      OR (status = 'suspended' AND suspended_at IS NOT NULL AND deletion_requested_at IS NULL AND deleted_at IS NULL)
      OR (status = 'pending_deletion' AND deletion_requested_at IS NOT NULL AND deleted_at IS NULL)
      OR (status = 'deleted' AND deletion_requested_at IS NOT NULL AND deleted_at IS NOT NULL
          AND deleted_at >= deletion_requested_at)
    SQL
  end

  def membership_lifecycle_constraint
    <<~SQL.squish
      (status = 'active' AND suspended_at IS NULL AND left_at IS NULL)
      OR (status = 'suspended' AND suspended_at IS NOT NULL AND left_at IS NULL)
      OR (status = 'left' AND left_at IS NOT NULL)
    SQL
  end
end
