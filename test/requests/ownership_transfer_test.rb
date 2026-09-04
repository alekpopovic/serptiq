# frozen_string_literal: true

require "test_helper"

class OwnershipTransferRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner_user = create_identity_user(display_name: "Request Previous Owner")
    @owner = create_organization_for(user: @owner_user, name: "Transfer Request Org", slug: "transfer-request")
    @target_user = create_identity_user(display_name: "Request New Owner")
    @target = Tenancy::Public.create_membership(actor_membership: @owner.membership, user: @target_user)
    @target_session = issue_identity_session(user: @target_user, at: @now - 2.minutes)
    @issued = issue_identity_session(user: @owner_user, at: @now - 1.minute)
    authenticate_request(@issued)
  end

  test "owner reviews consequences and submits a signed state-changing transfer" do
    get organization_settings_path(@owner.organization.slug)
    assert_response :success
    assert_select "a", text: "Review ownership transfer"

    get organization_ownership_transfer_path(@owner.organization.slug)
    assert_response :success
    assert_select "select[name='target_membership_id'] option", text: @target.display_name
    assert_select "input[name='confirmation']"
    assert_includes response.body, "billing, security, roles, integrations, exports and deletion requests"

    post organization_ownership_transfer_path(@owner.organization.slug), params: {
      target_membership_id: @target.id,
      confirmation: Tenancy::TransferOwnership::CONFIRMATION
    }

    assert_redirected_to dashboard_path
    assert_equal @target.id, @owner.organization.reload.current_ownership.membership_id
    assert_equal "privilege_changed", @target_session.session.reload.revoke_reason
    refute_equal @issued.token, response.cookies.fetch(Identity::SessionCookie.name)

    follow_redirect!
    assert_response :success
    get organization_dashboard_path(@owner.organization.slug)
    assert_response :forbidden
  end

  test "stale session invalid target and missing confirmation leave ownership unchanged" do
    @issued.session.update!(authenticated_at: @now - 16.minutes)
    post organization_ownership_transfer_path(@owner.organization.slug), params: {
      target_membership_id: @target.id,
      confirmation: Tenancy::TransferOwnership::CONFIRMATION
    }
    assert_response :unauthorized
    assert_current_owner(@owner.membership)

    @issued.session.update!(authenticated_at: @now - 1.minute)
    authenticate_request(@issued)
    foreign = create_organization_for(slug: "foreign-transfer-request")
    get organization_ownership_transfer_path(foreign.organization.slug)
    assert_response :forbidden
    refute_includes response.body, foreign.organization.name

    post organization_ownership_transfer_path(@owner.organization.slug), params: {
      target_membership_id: foreign.membership.id,
      confirmation: Tenancy::TransferOwnership::CONFIRMATION
    }
    assert_response :forbidden
    refute_includes response.body, foreign.membership.display_name
    assert_current_owner(@owner.membership)

    post organization_ownership_transfer_path(@owner.organization.slug), params: {
      target_membership_id: @target.id,
      confirmation: ""
    }
    assert_response :unprocessable_content
    assert_select "[role='alert']", text: /Confirm the exact transfer statement/
    assert_current_owner(@owner.membership)
  end

  test "non-owner and suspended target cannot transfer ownership" do
    analyst_user = create_identity_user(display_name: "Unauthorized Analyst")
    analyst = Tenancy::Public.create_membership(actor_membership: @owner.membership, user: analyst_user)
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: analyst.id,
      role_id: Authorization::Role.find_by!(key: "organization_admin").id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )
    reset!
    authenticate_request(issue_identity_session(user: analyst_user, at: @now - 1.minute))
    get organization_ownership_transfer_path(@owner.organization.slug)
    assert_response :forbidden

    reset!
    authenticate_request(@issued)
    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership,
      target_membership_id: @target.id,
      operation: "suspend"
    )
    post organization_ownership_transfer_path(@owner.organization.slug), params: {
      target_membership_id: @target.id,
      confirmation: Tenancy::TransferOwnership::CONFIRMATION
    }
    assert_response :forbidden
    assert_current_owner(@owner.membership)
  end

  private

  def assert_current_owner(membership)
    assert_equal membership.id, @owner.organization.reload.current_ownership.membership_id
    assert_equal 1, Tenancy::OrganizationOwnership.where(
      organization_id: @owner.organization.id,
      ended_at: nil
    ).count
  end
end
