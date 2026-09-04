# frozen_string_literal: true

class CreateTeamsAndTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :teams, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
      t.citext :name, null: false
      t.string :status, limit: 24, null: false, default: "active"
      t.datetime :archived_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end
    add_index :teams, %i[organization_id id], unique: true, name: "index_teams_on_organization_and_id"
    add_index :teams, %i[organization_id name], unique: true, where: "archived_at IS NULL",
      name: "index_teams_on_active_organization_and_name"
    add_index :teams, %i[organization_id status created_at], name: "index_teams_on_org_status_and_created"
    add_check_constraint :teams, "char_length(name) BETWEEN 2 AND 120 AND name = btrim(name)",
      name: "teams_name_format"
    add_check_constraint :teams, "status IN ('active', 'archived')", name: "teams_status_allowlist"
    add_check_constraint :teams,
      "(status = 'active' AND archived_at IS NULL) OR (status = 'archived' AND archived_at IS NOT NULL)",
      name: "teams_lifecycle_consistency"

    create_table :team_memberships, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :team_id, null: false
      t.uuid :membership_id, null: false
      t.uuid :added_by_membership_id, null: false
      t.datetime :added_at, null: false
      t.datetime :removed_at

      t.timestamps
    end
    add_foreign_key :team_memberships, :organizations, on_delete: :restrict
    add_foreign_key :team_memberships, :teams,
      column: %i[organization_id team_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_team_memberships_same_org_team"
    add_foreign_key :team_memberships, :memberships,
      column: %i[organization_id membership_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_team_memberships_same_org_member"
    add_foreign_key :team_memberships, :memberships,
      column: %i[organization_id added_by_membership_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_team_memberships_same_org_actor"
    add_index :team_memberships, %i[team_id membership_id], unique: true, where: "removed_at IS NULL",
      name: "index_team_memberships_on_active_team_and_member"
    add_index :team_memberships, %i[organization_id membership_id removed_at],
      name: "index_team_memberships_on_org_member_and_removed"
    add_index :team_memberships, %i[organization_id team_id added_at],
      name: "index_team_memberships_on_org_team_and_added"
    add_check_constraint :team_memberships, "removed_at IS NULL OR removed_at >= added_at",
      name: "team_memberships_timestamp_order"
  end
end
