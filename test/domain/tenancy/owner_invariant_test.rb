# frozen_string_literal: true

require "test_helper"

class MembershipLifecycleAuthorizationProbeJob < ApplicationJob
  requires_permission "organization.read"

  class_attribute :executions, default: 0

  def perform(user_id:, organization_id:)
    authorize_job!(user_id: user_id, organization_id: organization_id) do
      self.class.executions += 1
    end
  end
end

class OwnerInvariantTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "central-owner-invariant")
  end

  test "every owner-affecting path preserves the explicit current owner" do
    %w[suspend remove].each do |operation|
      error = assert_raises(Tenancy::LastOwnerConflict) do
        Tenancy::Public.change_membership_status(
          actor_membership: @owner.membership,
          target_membership_id: @owner.membership.id,
          operation: operation
        )
      end
      assert_equal "last_owner_transfer_required", error.reason_code
    end

    team = Tenancy::Public.create_team(actor_membership: @owner.membership, name: "Owner Team")
    Tenancy::Public.add_team_member(
      actor_membership: @owner.membership,
      team_id: team.id,
      membership_id: @owner.membership.id
    )
    Tenancy::Public.remove_team_member(
      actor_membership: @owner.membership,
      team_id: team.id,
      membership_id: @owner.membership.id
    )
    assert_predicate @owner.membership.reload, :owner?

    assignment = Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: @owner.membership.id,
      role_id: Authorization::Role.find_by!(key: "viewer").id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )
    Authorization::Public.revoke_role(
      actor_membership: @owner.membership,
      assignment_id: assignment.id
    )
    assert_predicate @owner.membership.reload, :owner?

    Tenancy::Public.transition_organization(actor_membership: @owner.membership, to: "suspended")
    assert_predicate @owner.membership.reload, :owner?
    assert_equal @owner.membership.id, @owner.organization.reload.current_ownership.membership_id
    assert_empty Tenancy::Public.ownership_consistency_issues
  end

  test "member removal revokes execution access while preserving attribution rows" do
    member_user = create_identity_user(display_name: "Historical Actor")
    member = Tenancy::Public.create_membership(actor_membership: @owner.membership, user: member_user)
    session = issue_identity_session(user: member_user)
    team = Tenancy::Public.create_team(actor_membership: @owner.membership, name: "Historical Team")
    team_membership = Tenancy::Public.add_team_member(
      actor_membership: @owner.membership,
      team_id: team.id,
      membership_id: member.id
    ).record
    assignment = Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: member.id,
      role_id: Authorization::Role.find_by!(key: "viewer").id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )

    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership,
      target_membership_id: member.id,
      operation: "remove"
    )

    assert_predicate member.reload, :removed?
    assert_equal "privilege_changed", session.session.reload.revoke_reason
    assert_nil assignment.reload.revoked_at
    assert_nil team_membership.reload.removed_at
    refute_predicate team_membership, :effective?
    assert_empty Authorization::Public.effective_permissions(
      organization_id: @owner.organization.id,
      membership_id: member.id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    ).permission_keys

    MembershipLifecycleAuthorizationProbeJob.executions = 0
    assert_raises(Tenancy::OrganizationAccessDenied) do
      MembershipLifecycleAuthorizationProbeJob.perform_now(
        user_id: member_user.id,
        organization_id: @owner.organization.id
      )
    end
    assert_equal 0, MembershipLifecycleAuthorizationProbeJob.executions
  end

  test "deferred database triggers reject an inactive committed current owner" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Tenancy::Membership.transaction(requires_new: true) do
        @owner.membership.update_columns(
          status: "suspended",
          suspended_at: Time.current,
          updated_at: Time.current
        )
        Tenancy::Membership.connection.execute(
          "SET CONSTRAINTS fk_current_ownership_active_membership IMMEDIATE"
        )
      end
    end

    assert_predicate @owner.membership.reload, :active?
    assert_empty Tenancy::Public.ownership_consistency_issues
  end
end
