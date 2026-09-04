# frozen_string_literal: true

require "test_helper"

class RoleAssignmentConstraintsTest < ActiveSupport::TestCase
  test "database rejects every cross-tenant assignment dimension and deny semantics" do
    Authorization::Public.sync_catalog
    owner = create_organization_for(slug: "assignment-db-owner")
    foreign = create_organization_for(slug: "assignment-db-foreign")
    member = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: create_identity_user(display_name: "Database Member")
    )
    foreign_team = Tenancy::Public.create_team(actor_membership: foreign.membership, name: "Foreign Team")
    project_id = SecureRandom.uuid
    foreign_project_id = SecureRandom.uuid
    Authorization::Public.register_scope(
      organization_id: owner.organization.id, scope_type: "Project", scope_id: project_id
    )
    Authorization::Public.register_scope(
      organization_id: foreign.organization.id, scope_type: "Project", scope_id: foreign_project_id
    )
    viewer = Authorization::Role.find_by!(system: true, key: "viewer")
    now = Time.current
    valid = {
      organization_id: owner.organization.id,
      grantee_type: "Membership",
      grantee_id: member.id,
      membership_grantee_id: member.id,
      team_grantee_id: nil,
      role_id: viewer.id,
      role_system: true,
      role_organization_id: nil,
      scope_type: "Project",
      scope_id: project_id,
      granted_by_membership_id: owner.membership.id,
      effect: "allow",
      created_at: now,
      updated_at: now
    }

    assert_database_rejects(valid.merge(
      grantee_id: foreign.membership.id,
      membership_grantee_id: foreign.membership.id
    ))
    assert_database_rejects(valid.merge(
      grantee_type: "Team",
      grantee_id: foreign_team.id,
      membership_grantee_id: nil,
      team_grantee_id: foreign_team.id
    ))
    assert_database_rejects(valid.merge(granted_by_membership_id: foreign.membership.id))
    assert_database_rejects(valid.merge(scope_id: foreign_project_id))
    assert_database_rejects(valid.merge(effect: "deny"))

    foreign_role = Authorization::Role.create!(
      organization_id: foreign.organization.id,
      key: "foreign_database_role",
      name: "Foreign Database Role",
      system: false,
      mutable: true,
      assignable_scopes: [ "project" ]
    )
    assert_database_rejects(valid.merge(
      role_id: foreign_role.id,
      role_system: false,
      role_organization_id: owner.organization.id
    ))

    assert_raises(ActiveRecord::StatementInvalid) do
      Authorization::ScopeReference.transaction(requires_new: true) do
        Authorization::ScopeReference.insert!({
          id: SecureRandom.uuid,
          organization_id: owner.organization.id,
          scope_type: "Property",
          project_id: foreign_project_id,
          project_scope_type: "Project",
          status: "active",
          created_at: now,
          updated_at: now
        })
      end
    end
  end

  private

  def assert_database_rejects(attributes)
    assert_raises(ActiveRecord::StatementInvalid) do
      Authorization::RoleAssignment.transaction(requires_new: true) do
        Authorization::RoleAssignment.insert!(attributes)
      end
    end
  end
end
