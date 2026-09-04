# frozen_string_literal: true

require "test_helper"

class MembershipLifecycleRequestTest < ActionDispatch::IntegrationTest
  setup do
    @owner_user = create_identity_user
    @owner = create_organization_for(user: @owner_user, name: "Member Workspace", slug: "member-workspace")
    @owner_session = issue_identity_session(user: @owner_user)
    authenticate_request(@owner_session)
  end

  test "owner can page safe member labels without foreign names or email addresses" do
    26.times do |index|
      user = create_identity_user(display_name: format("Member %02d", index))
      Tenancy::Public.create_membership(actor_membership: @owner.membership, user: user)
    end
    foreign = create_organization_for(name: "Foreign Organization", slug: "member-list-foreign")
    foreign_user = create_identity_user(display_name: "Foreign Hidden Member")
    Tenancy::Public.create_membership(actor_membership: foreign.membership, user: foreign_user)

    get organization_members_path(@owner.organization.slug)
    assert_response :success
    assert_select "tbody tr", count: 25
    assert_select "nav[aria-label='Member pages'] a", text: "Next"
    refute_includes response.body, "Foreign Hidden Member"
    refute_includes response.body, foreign_user.primary_email

    get organization_members_path(@owner.organization.slug, page: 2)
    assert_response :success
    assert_select "tbody tr", count: 2
    assert_select "nav[aria-label='Member pages'] a", text: "Previous"
  end

  test "suspension revokes the target session and reactivation requires a new sign in" do
    target_user = create_identity_user(display_name: "Lifecycle Target")
    target = Tenancy::Public.create_membership(actor_membership: @owner.membership, user: target_user)
    target_session = issue_identity_session(user: target_user)

    patch suspend_organization_member_path(@owner.organization.slug, target.id)
    assert_redirected_to organization_member_path(@owner.organization.slug, target.id)
    assert target.reload.suspended?
    assert_not_nil target_session.session.reload.revoked_at

    reset!
    authenticate_request(target_session)
    get organization_dashboard_path(@owner.organization.slug)
    assert_redirected_to sign_in_path(return_to: organization_dashboard_path(@owner.organization.slug))

    reset!
    authenticate_request(@owner_session)
    patch reactivate_organization_member_path(@owner.organization.slug, target.id)
    assert target.reload.active?

    reset!
    authenticate_request(issue_identity_session(user: target_user))
    get organization_dashboard_path(@owner.organization.slug)
    assert_response :success
  end

  test "cross-tenant IDs and current-owner mutations are denied without state change" do
    foreign = create_organization_for(slug: "member-action-foreign")

    patch remove_organization_member_path(@owner.organization.slug, foreign.membership.id)
    assert_response :forbidden
    assert foreign.membership.reload.active?

    patch suspend_organization_member_path(@owner.organization.slug, @owner.membership.id)
    assert_response :forbidden
    assert @owner.membership.reload.active?
  end

  test "removed member detail retains attribution and exposes no reactivation action" do
    target = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Retained Author")
    )
    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership,
      target_membership_id: target.id,
      operation: "remove"
    )

    get organization_member_path(@owner.organization.slug, target.id)
    assert_response :success
    assert_select "h1", text: "Retained Author"
    assert_select ".so-badge", text: "Removed"
    assert_select "form[action='#{reactivate_organization_member_path(@owner.organization.slug, target.id)}']", count: 0
    assert_includes response.body, "Historical attribution"
  end
end
