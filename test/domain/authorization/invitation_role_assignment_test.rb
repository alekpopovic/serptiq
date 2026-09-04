# frozen_string_literal: true

require "test_helper"

class AuthorizationInvitationRoleAssignmentTest < ActiveSupport::TestCase
  class RejectingAssigner
    def call(**)
      raise Authorization::AssignmentDenied.new(reason_code: "grant_authority_missing")
    end
  end

  test "role-application failure rolls membership and invitation acceptance back together" do
    Authorization::Public.sync_catalog
    owner = create_organization_for(slug: "atomic-invitation-role")
    user = create_identity_user(display_name: "Atomic Invitee")
    create_verified_provider_identity(user: user, email: "atomic-invitee@example.test")
    issued = Tenancy::IssueInvitation.new(delivery: ->(**) { }).call(
      actor_membership: owner.membership,
      email: "atomic-invitee@example.test",
      initial_role_key: "viewer"
    )

    error = assert_raises(Authorization::AssignmentDenied) do
      Authorization::AcceptInvitation.new(assigner: RejectingAssigner.new).call(
        token: issued.token,
        user: user,
        rate_limit_key: "192.0.2.25"
      )
    end

    assert_equal "grant_authority_missing", error.reason_code
    assert issued.invitation.reload.pending?
    refute Tenancy::Membership.exists?(organization_id: owner.organization.id, user_id: user.id)
    refute Authorization::RoleAssignment.exists?(organization_id: owner.organization.id)
  end
end
