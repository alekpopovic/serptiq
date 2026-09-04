# frozen_string_literal: true

require "test_helper"

class TenancyTeamTest < ActiveSupport::TestCase
  test "owner creates renames and archives a uniquely named team" do
    owner = create_organization_for(slug: "team-lifecycle")
    team = Tenancy::Public.create_team(actor_membership: owner.membership, name: "  SEO Team  ")
    assert_equal "SEO Team", team.name
    assert team.active?

    assert_raises(ActiveRecord::RecordInvalid) do
      Tenancy::Public.create_team(actor_membership: owner.membership, name: "seo team")
    end
    renamed = Tenancy::Public.rename_team(
      actor_membership: owner.membership,
      team_id: team.id,
      name: "Platform Team"
    )
    assert_equal "Platform Team", renamed.name

    result = Tenancy::Public.archive_team(actor_membership: owner.membership, team_id: team.id)
    assert result.changed?
    assert result.record.archived?
    refute Tenancy::Public.archive_team(actor_membership: owner.membership, team_id: team.id).changed?
    assert_raises(Tenancy::InvalidOrganizationTransition) do
      Tenancy::Public.rename_team(actor_membership: owner.membership, team_id: team.id, name: "No Rename")
    end
  end

  test "same-organization active members can be added idempotently and removed" do
    owner = create_organization_for(slug: "team-membership")
    target = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: create_identity_user(display_name: "Team Member")
    )
    team = Tenancy::Public.create_team(actor_membership: owner.membership, name: "Editors")

    added = Tenancy::Public.add_team_member(
      actor_membership: owner.membership,
      team_id: team.id,
      membership_id: target.id
    )
    assert added.changed?
    assert added.record.effective?
    refute Tenancy::Public.add_team_member(
      actor_membership: owner.membership,
      team_id: team.id,
      membership_id: target.id
    ).changed?

    removed = Tenancy::Public.remove_team_member(
      actor_membership: owner.membership,
      team_id: team.id,
      membership_id: target.id
    )
    assert removed.changed?
    assert_not_nil removed.record.removed_at
    refute Tenancy::Public.remove_team_member(
      actor_membership: owner.membership,
      team_id: team.id,
      membership_id: target.id
    ).changed?
  end

  test "foreign and inactive memberships never become effective principals" do
    owner = create_organization_for(slug: "team-effective")
    foreign = create_organization_for(slug: "team-foreign")
    target = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: create_identity_user(display_name: "Effective Member")
    )
    team = Tenancy::Public.create_team(actor_membership: owner.membership, name: "Developers")

    assert_raises(Tenancy::OrganizationAccessDenied) do
      Tenancy::Public.add_team_member(
        actor_membership: owner.membership,
        team_id: team.id,
        membership_id: foreign.membership.id
      )
    end
    Tenancy::Public.add_team_member(
      actor_membership: owner.membership,
      team_id: team.id,
      membership_id: target.id
    )
    principals = Tenancy::Public.authorization_principals(
      organization_id: owner.organization.id,
      membership_id: target.id
    )
    assert_equal target.id, principals.membership_id
    assert_equal [ team.id ], principals.team_ids

    Tenancy::Public.change_membership_status(
      actor_membership: owner.membership,
      target_membership_id: target.id,
      operation: "suspend"
    )
    refute Tenancy::Public.authorization_principals(
      organization_id: owner.organization.id,
      membership_id: target.id
    ).active?

    Tenancy::Public.change_membership_status(
      actor_membership: owner.membership,
      target_membership_id: target.id,
      operation: "reactivate"
    )
    assert_equal [ team.id ], Tenancy::Public.authorization_principals(
      organization_id: owner.organization.id,
      membership_id: target.id
    ).team_ids

    Tenancy::Public.archive_team(actor_membership: owner.membership, team_id: team.id)
    assert_empty Tenancy::Public.authorization_principals(
      organization_id: owner.organization.id,
      membership_id: target.id
    ).team_ids
  end

  test "database composite keys reject a member from another organization" do
    owner = create_organization_for(slug: "team-db-owner")
    foreign = create_organization_for(slug: "team-db-foreign")
    team = Tenancy::Public.create_team(actor_membership: owner.membership, name: "Database Team")
    now = Time.current

    assert_raises(ActiveRecord::StatementInvalid) do
      Tenancy::TeamMembership.transaction(requires_new: true) do
        Tenancy::TeamMembership.insert!({
          organization_id: owner.organization.id,
          team_id: team.id,
          membership_id: foreign.membership.id,
          added_by_membership_id: owner.membership.id,
          added_at: now,
          created_at: now,
          updated_at: now
        })
      end
    end
  end
end
