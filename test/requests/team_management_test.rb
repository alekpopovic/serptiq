# frozen_string_literal: true

require "test_helper"

class TeamManagementRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user
    @owner = create_organization_for(user: @user, name: "Team Workspace", slug: "team-workspace")
    authenticate_request(issue_identity_session(user: @user))
  end

  test "team list is paginated and member search stays inside the current organization" do
    26.times { |index| Tenancy::Public.create_team(actor_membership: @owner.membership, name: format("Team %02d", index)) }
    candidate = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Matching Local Member")
    )
    foreign = create_organization_for(slug: "team-request-foreign")
    Tenancy::Public.create_membership(
      actor_membership: foreign.membership,
      user: create_identity_user(display_name: "Matching Foreign Secret")
    )

    get organization_teams_path(@owner.organization.slug)
    assert_response :success
    assert_select "tbody tr", count: 25
    assert_select "nav[aria-label='Team pages'] a", text: "Next"

    team = Tenancy::Team.where(organization_id: @owner.organization.id).first
    get organization_team_path(@owner.organization.slug, team.id), params: { q: "Matching" }
    assert_response :success
    assert_includes response.body, candidate.display_name
    refute_includes response.body, "Matching Foreign Secret"
  end

  test "foreign team and membership IDs are denied without an attachment" do
    local_team = Tenancy::Public.create_team(actor_membership: @owner.membership, name: "Local Team")
    foreign = create_organization_for(slug: "foreign-team-action")
    foreign_team = Tenancy::Public.create_team(actor_membership: foreign.membership, name: "Foreign Team")

    post organization_team_members_path(@owner.organization.slug, local_team.id),
      params: { membership_id: foreign.membership.id }
    assert_response :forbidden
    assert_empty local_team.team_memberships

    patch archive_organization_team_path(@owner.organization.slug, foreign_team.id)
    assert_response :forbidden
    assert foreign_team.reload.active?
  end

  test "archived team is read-only and has no effective authorization principals" do
    target = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Archived Team Member")
    )
    team = Tenancy::Public.create_team(actor_membership: @owner.membership, name: "Archived Team")
    Tenancy::Public.add_team_member(
      actor_membership: @owner.membership,
      team_id: team.id,
      membership_id: target.id
    )

    patch archive_organization_team_path(@owner.organization.slug, team.id)
    assert_redirected_to organization_team_path(@owner.organization.slug, team.id)
    assert team.reload.archived?

    get organization_team_path(@owner.organization.slug, team.id)
    assert_response :success
    assert_select "form[action='#{organization_team_path(@owner.organization.slug, team.id)}']", count: 0
    assert_includes response.body, "contribute no future role grants"
    assert_empty Tenancy::Public.authorization_principals(
      organization_id: @owner.organization.id,
      membership_id: target.id
    ).team_ids
  end
end
