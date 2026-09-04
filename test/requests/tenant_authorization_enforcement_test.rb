# frozen_string_literal: true

require "test_helper"

class TenantAuthorizationEnforcementTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @owner_user = create_identity_user(display_name: "Authorization Owner")
    @owner = create_organization_for(user: @owner_user, name: "Authorization Workspace", slug: "authorization-workspace")
    @analyst = add_member_with_role("analyst", display_name: "Read Only Analyst")
    @viewer = add_member_with_role("viewer", display_name: "Limited Viewer")
    @target = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Local Mutation Target")
    )
    @team = Tenancy::Public.create_team(actor_membership: @owner.membership, name: "Local Secret Team")
    @invitation = issue_invitation("pending-local@example.test")
  end

  test "read permissions expose tenant indexes but all mutation controls and endpoints stay denied" do
    authenticate_as(@analyst)

    get organization_dashboard_path(@owner.organization.slug)
    assert_response :success

    get organization_settings_path(@owner.organization.slug)
    assert_response :success
    assert_select "input[name='organization[name]']", count: 0
    assert_select "button", text: "Save organization settings", count: 0

    get organization_members_path(@owner.organization.slug)
    assert_response :success
    assert_includes response.body, @target.display_name
    get organization_member_path(@owner.organization.slug, @target.id)
    assert_response :success
    assert_select "button", text: /Suspend member|Remove member|Reactivate member/, count: 0

    get organization_invitations_path(@owner.organization.slug)
    assert_response :success
    assert_select "a", text: "Invite a member", count: 0
    assert_select "button", text: /Revoke|Resend/, count: 0

    get organization_teams_path(@owner.organization.slug)
    assert_response :success
    assert_select "a", text: "Create team", count: 0
    get organization_team_path(@owner.organization.slug, @team.id)
    assert_response :success
    assert_select "button", text: /Save team name|Add member|Remove|Archive team/, count: 0

    assert_denied_mutations
    assert_equal "Authorization Workspace", @owner.organization.reload.name
    assert_predicate @target.reload, :active?
    assert_predicate @team.reload, :active?
    assert_predicate @invitation.reload, :pending?
  end

  test "organization administrator decisions authorize matching domain operations" do
    administrator = add_member_with_role("organization_admin", display_name: "Organization Administrator")
    authenticate_as(administrator)

    patch organization_settings_path(@owner.organization.slug), params: {
      organization: {
        name: "Administrator Updated Workspace",
        slug: @owner.organization.slug,
        default_locale: "en",
        time_zone: "UTC"
      }
    }
    assert_redirected_to organization_settings_path(@owner.organization.slug)
    assert_equal "Administrator Updated Workspace", @owner.organization.reload.name

    assert_difference -> { Tenancy::Team.where(organization_id: @owner.organization.id).count }, 1 do
      post organization_teams_path(@owner.organization.slug), params: { team: { name: "Administrator Team" } }
    end
    assert_response :see_other

    assert_difference -> { Tenancy::Invitation.where(organization_id: @owner.organization.id).count }, 1 do
      post organization_invitations_path(@owner.organization.slug), params: { email: "admin-invite@example.test" }
    end
    assert_response :see_other

    patch suspend_organization_member_path(@owner.organization.slug, @target.id)
    assert_response :see_other
    assert_predicate @target.reload, :suspended?
  end

  test "missing index permissions deny before any tenant list can leak" do
    authenticate_as(@viewer)

    [
      organization_members_path(@owner.organization.slug),
      organization_invitations_path(@owner.organization.slug),
      organization_teams_path(@owner.organization.slug)
    ].each do |path|
      get path
      assert_response :forbidden
      refute_includes response.body, "Local Mutation Target"
      refute_includes response.body, "pending-local@example.test"
      refute_includes response.body, "Local Secret Team"
    end
  end

  test "JSON authorization denial uses the bounded API contract" do
    authenticate_as(@viewer)

    get organization_members_path(@owner.organization.slug), as: :json

    assert_response :forbidden
    payload = response.parsed_body.fetch("error")
    assert_equal %w[code reason_code request_id], payload.keys.sort
    assert_equal "authorization_denied", payload.fetch("code")
    assert_equal "permission_missing", payload.fetch("reason_code")
    assert_predicate payload.fetch("request_id"), :present?
    refute_includes response.body, @owner.organization.id
  end

  test "every existing tenant resource route rejects a foreign organization before exposure" do
    foreign = create_organization_for(name: "Foreign Hidden Workspace", slug: "foreign-hidden-workspace")
    foreign_target = Tenancy::Public.create_membership(
      actor_membership: foreign.membership,
      user: create_identity_user(display_name: "Foreign Hidden Member")
    )
    foreign_team = Tenancy::Public.create_team(actor_membership: foreign.membership, name: "Foreign Hidden Team")
    foreign_invitation = Tenancy::IssueInvitation.new(delivery: ->(**) { }).call(
      actor_membership: foreign.membership,
      email: "foreign-hidden@example.test"
    ).invitation
    authenticate_as(@analyst)

    tenant_requests(foreign, foreign_target, foreign_team, foreign_invitation).each do |verb, path, params|
      public_send(verb, path, params: params)
      assert_response :forbidden, "expected #{verb.upcase} #{path} to be forbidden"
      refute_includes response.body, "Foreign Hidden Workspace"
      refute_includes response.body, "Foreign Hidden Member"
      refute_includes response.body, "Foreign Hidden Team"
      refute_includes response.body, "foreign-hidden@example.test"
    end
  end

  private

  def add_member_with_role(role_key, display_name:)
    user = create_identity_user(display_name: display_name)
    membership = Tenancy::Public.create_membership(actor_membership: @owner.membership, user: user)
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: membership.id,
      role_id: Authorization::Role.find_by!(key: role_key).id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )
    membership
  end

  def authenticate_as(membership)
    reset!
    authenticate_request(issue_identity_session(user: membership.user))
  end

  def issue_invitation(email)
    Tenancy::IssueInvitation.new(delivery: ->(**) { }).call(
      actor_membership: @owner.membership,
      email: email
    ).invitation
  end

  def assert_denied_mutations
    requests = [
      [ :patch, organization_settings_path(@owner.organization.slug), { organization: { name: "Stolen", slug: "stolen", default_locale: "en", time_zone: "UTC" } } ],
      [ :get, new_organization_invitation_path(@owner.organization.slug), {} ],
      [ :post, organization_invitations_path(@owner.organization.slug), { email: "blocked@example.test" } ],
      [ :patch, revoke_organization_invitation_path(@owner.organization.slug, @invitation.id), {} ],
      [ :post, resend_organization_invitation_path(@owner.organization.slug, @invitation.id), {} ],
      [ :patch, suspend_organization_member_path(@owner.organization.slug, @target.id), {} ],
      [ :patch, reactivate_organization_member_path(@owner.organization.slug, @target.id), {} ],
      [ :patch, remove_organization_member_path(@owner.organization.slug, @target.id), {} ],
      [ :get, new_organization_team_path(@owner.organization.slug), {} ],
      [ :post, organization_teams_path(@owner.organization.slug), { team: { name: "Blocked" } } ],
      [ :patch, organization_team_path(@owner.organization.slug, @team.id), { team: { name: "Blocked" } } ],
      [ :patch, archive_organization_team_path(@owner.organization.slug, @team.id), {} ],
      [ :post, organization_team_members_path(@owner.organization.slug, @team.id), { membership_id: @target.id } ],
      [ :delete, organization_team_member_path(@owner.organization.slug, @team.id, @target.id), {} ]
    ]
    requests.each do |verb, path, params|
      public_send(verb, path, params: params)
      assert_response :forbidden, "expected #{verb.upcase} #{path} to be forbidden"
    end
  end

  def tenant_requests(foreign, target, team, invitation)
    slug = foreign.organization.slug
    [
      [ :get, organization_dashboard_path(slug), {} ],
      [ :get, switch_organization_path(slug), {} ],
      [ :get, organization_settings_path(slug), {} ],
      [ :patch, organization_settings_path(slug), { organization: { name: "No", slug: "no", default_locale: "en", time_zone: "UTC" } } ],
      [ :get, organization_members_path(slug), {} ],
      [ :get, organization_member_path(slug, target.id), {} ],
      [ :patch, suspend_organization_member_path(slug, target.id), {} ],
      [ :patch, reactivate_organization_member_path(slug, target.id), {} ],
      [ :patch, remove_organization_member_path(slug, target.id), {} ],
      [ :get, organization_invitations_path(slug), {} ],
      [ :get, new_organization_invitation_path(slug), {} ],
      [ :post, organization_invitations_path(slug), { email: "no@example.test" } ],
      [ :patch, revoke_organization_invitation_path(slug, invitation.id), {} ],
      [ :post, resend_organization_invitation_path(slug, invitation.id), {} ],
      [ :get, organization_teams_path(slug), {} ],
      [ :get, new_organization_team_path(slug), {} ],
      [ :post, organization_teams_path(slug), { team: { name: "No" } } ],
      [ :get, organization_team_path(slug, team.id), {} ],
      [ :patch, organization_team_path(slug, team.id), { team: { name: "No" } } ],
      [ :patch, archive_organization_team_path(slug, team.id), {} ],
      [ :post, organization_team_members_path(slug, team.id), { membership_id: target.id } ],
      [ :delete, organization_team_member_path(slug, team.id, target.id), {} ]
    ]
  end
end
