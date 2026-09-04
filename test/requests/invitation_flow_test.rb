# frozen_string_literal: true

require "test_helper"

class InvitationFlowRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @owner_user = create_identity_user(display_name: "Request Owner")
    @owner = create_organization_for(user: @owner_user, name: "Request Workspace", slug: "request-workspace")
    authenticate_request(issue_identity_session(user: @owner_user))
  end

  test "owner issues without account disclosure and raw token exists only in mail and encrypted cookie" do
    assert_difference -> { ActionMailer::Base.deliveries.length } => 1 do
      post organization_invitations_path(@owner.organization.slug), params: {
        email: "unknown@example.test", initial_role_key: "viewer"
      }
    end
    assert_redirected_to organization_invitations_path(@owner.organization.slug)
    assert_equal "If the address can receive mail, a new invitation was sent.", flash[:notice]

    invitation = Tenancy::Invitation.order(:created_at).last
    mail = ActionMailer::Base.deliveries.last
    token = mail.body.encoded[/so_i1_[A-Za-z0-9_-]{43}/]
    assert token
    refute_includes invitation.attributes.values.map(&:to_s), token

    reset!
    get invitation_entry_path(token: token)
    assert_redirected_to sign_in_path(return_to: invitation_review_path)
    refute_includes response.location, token
    assert_match(/HttpOnly/i, response.headers["Set-Cookie"])
  end

  test "invalid replay and wrong-email links render the same accessible denial" do
    issued = issue_direct(email: "bound@example.test")
    wrong_user = create_identity_user
    create_verified_provider_identity(user: wrong_user, email: "wrong@example.test")
    reset!
    authenticate_request(issue_identity_session(user: wrong_user))

    get invitation_entry_path(token: issued.token)
    follow_redirect!
    wrong_body = css_select("h1").sole.text
    assert_response :forbidden

    get invitation_entry_path(token: "so_i1_#{'x' * 43}")
    follow_redirect!
    assert_response :forbidden
    assert_equal wrong_body, css_select("h1").sole.text
    assert_select "[role='alert']"
  end

  test "ordinary and foreign members cannot manage invitations" do
    member_user = create_identity_user
    Tenancy::Public.create_membership(actor_membership: @owner.membership, user: member_user)
    foreign = create_organization_for(slug: "request-invite-foreign")

    reset!
    authenticate_request(issue_identity_session(user: member_user))
    assert_no_difference -> { Tenancy::Invitation.count } do
      post organization_invitations_path(@owner.organization.slug), params: { email: "blocked@example.test" }
    end
    assert_response :forbidden

    post organization_invitations_path(foreign.organization.slug), params: { email: "leak@example.test" }
    assert_response :forbidden
    refute_includes response.body, foreign.organization.name
  end

  test "acceptance atomically converts the bounded initial role intent into an effective grant" do
    target_user = create_identity_user(display_name: "Role Invitee")
    create_verified_provider_identity(user: target_user, email: "role-invitee@example.test")
    issued = issue_direct(email: "role-invitee@example.test", initial_role_key: "viewer")

    reset!
    authenticate_request(issue_identity_session(user: target_user))
    get invitation_entry_path(token: issued.token)
    follow_redirect!
    assert_response :success
    post accept_invitation_path

    membership = Tenancy::Membership.find_by!(
      organization_id: @owner.organization.id, user_id: target_user.id
    )
    assert_redirected_to organization_dashboard_path(@owner.organization.slug)
    assignment = Authorization::RoleAssignment.find_by!(
      organization_id: @owner.organization.id,
      grantee_type: "Membership",
      grantee_id: membership.id,
      scope_type: "Organization",
      scope_id: @owner.organization.id,
      revoked_at: nil
    )
    assert_equal "viewer", assignment.role.key
    assert Authorization::Public.effective_permissions(
      organization_id: @owner.organization.id,
      membership_id: membership.id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    ).include?("organization.read")
  end

  private

  def issue_direct(email:, initial_role_key: nil)
    Tenancy::IssueInvitation.new(delivery: ->(**) { }).call(
      actor_membership: @owner.membership, email: email, initial_role_key: initial_role_key
    )
  end
end
