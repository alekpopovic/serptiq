# frozen_string_literal: true

class CreateScopedRoleAssignments < ActiveRecord::Migration[8.1]
  def change
    create_scope_references
    create_role_assignments
  end

  private

  def create_scope_references
    create_table :authorization_scope_references, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.string :scope_type, limit: 24, null: false
      t.uuid :project_id
      t.string :project_scope_type, limit: 24
      t.string :status, limit: 24, null: false, default: "active"
      t.datetime :archived_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end
    add_foreign_key :authorization_scope_references, :organizations, on_delete: :restrict
    add_index :authorization_scope_references, %i[organization_id id scope_type], unique: true,
      name: "index_authorization_scopes_on_org_id_and_type"
    add_index :authorization_scope_references, %i[organization_id project_id],
      name: "index_authorization_scopes_on_org_and_project"
    add_foreign_key :authorization_scope_references, :authorization_scope_references,
      column: %i[organization_id project_id project_scope_type],
      primary_key: %i[organization_id id scope_type],
      on_delete: :restrict,
      name: "fk_authorization_property_scope_same_org_project"
    add_check_constraint :authorization_scope_references,
      "scope_type IN ('Organization', 'Project', 'Property')",
      name: "authorization_scopes_type_allowlist"
    add_check_constraint :authorization_scope_references,
      scope_shape_constraint,
      name: "authorization_scopes_shape"
    add_check_constraint :authorization_scope_references,
      "(status = 'active' AND archived_at IS NULL) OR (status = 'archived' AND archived_at IS NOT NULL)",
      name: "authorization_scopes_lifecycle"
  end

  def create_role_assignments
    add_index :roles, %i[id system], unique: true, name: "index_roles_on_id_and_system"

    create_table :role_assignments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.string :grantee_type, limit: 24, null: false
      t.uuid :grantee_id, null: false
      t.uuid :membership_grantee_id
      t.uuid :team_grantee_id
      t.uuid :role_id, null: false
      t.boolean :role_system, null: false
      t.uuid :role_organization_id
      t.string :scope_type, limit: 24, null: false
      t.uuid :scope_id, null: false
      t.uuid :granted_by_membership_id, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.uuid :revoked_by_membership_id
      t.string :effect, limit: 16, null: false, default: "allow"

      t.timestamps
    end

    add_foreign_key :role_assignments, :organizations, on_delete: :restrict
    add_foreign_key :role_assignments, :memberships,
      column: %i[organization_id membership_grantee_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_role_assignments_same_org_membership"
    add_foreign_key :role_assignments, :teams,
      column: %i[organization_id team_grantee_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_role_assignments_same_org_team"
    add_foreign_key :role_assignments, :memberships,
      column: %i[organization_id granted_by_membership_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_role_assignments_same_org_grantor"
    add_foreign_key :role_assignments, :memberships,
      column: %i[organization_id revoked_by_membership_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_role_assignments_same_org_revoker"
    add_foreign_key :role_assignments, :roles,
      column: %i[role_id role_system], primary_key: %i[id system], on_delete: :restrict,
      name: "fk_role_assignments_role_kind"
    add_foreign_key :role_assignments, :roles,
      column: %i[role_organization_id role_id], primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_role_assignments_same_org_custom_role"
    add_foreign_key :role_assignments, :authorization_scope_references,
      column: %i[organization_id scope_id scope_type],
      primary_key: %i[organization_id id scope_type], on_delete: :restrict,
      name: "fk_role_assignments_same_org_scope"

    add_index :role_assignments,
      %i[organization_id grantee_type grantee_id role_id scope_type scope_id],
      unique: true, where: "revoked_at IS NULL",
      name: "index_role_assignments_on_active_grant"
    add_index :role_assignments,
      %i[organization_id grantee_type grantee_id revoked_at expires_at],
      name: "index_role_assignments_on_effective_principal"
    add_index :role_assignments,
      %i[organization_id scope_type scope_id revoked_at expires_at],
      name: "index_role_assignments_on_effective_scope"
    add_index :role_assignments, :role_id

    add_check_constraint :role_assignments, grantee_shape_constraint,
      name: "role_assignments_grantee_shape"
    add_check_constraint :role_assignments, role_tenant_constraint,
      name: "role_assignments_role_tenant"
    add_check_constraint :role_assignments,
      "scope_type IN ('Organization', 'Project', 'Property')",
      name: "role_assignments_scope_type_allowlist"
    add_check_constraint :role_assignments, "effect = 'allow'",
      name: "role_assignments_allow_only"
    add_check_constraint :role_assignments,
      "(revoked_at IS NULL AND revoked_by_membership_id IS NULL) OR " \
        "(revoked_at IS NOT NULL AND revoked_by_membership_id IS NOT NULL)",
      name: "role_assignments_revocation_consistency"
    add_check_constraint :role_assignments,
      "expires_at IS NULL OR expires_at > created_at",
      name: "role_assignments_expiry_after_creation"
    add_check_constraint :role_assignments,
      "revoked_at IS NULL OR revoked_at >= created_at",
      name: "role_assignments_revocation_after_creation"
  end

  def scope_shape_constraint
    <<~SQL.squish
      (scope_type = 'Organization' AND id = organization_id
        AND project_id IS NULL AND project_scope_type IS NULL)
      OR (scope_type = 'Project' AND id <> organization_id
        AND project_id IS NULL AND project_scope_type IS NULL)
      OR (scope_type = 'Property' AND id <> organization_id
        AND project_id IS NOT NULL AND project_scope_type = 'Project' AND id <> project_id)
    SQL
  end

  def grantee_shape_constraint
    <<~SQL.squish
      (grantee_type = 'Membership' AND membership_grantee_id = grantee_id AND team_grantee_id IS NULL)
      OR (grantee_type = 'Team' AND team_grantee_id = grantee_id AND membership_grantee_id IS NULL)
    SQL
  end

  def role_tenant_constraint
    <<~SQL.squish
      (role_system = TRUE AND role_organization_id IS NULL)
      OR (role_system = FALSE AND role_organization_id = organization_id)
    SQL
  end
end
