# frozen_string_literal: true

module Tenancy
  class ManageInvitation
    def initialize(clock: -> { Time.current }, issuer: nil)
      @clock = clock
      @issuer = issuer || IssueInvitation.new(clock: clock)
    end

    def revoke(actor_membership:, invitation_id:, authorization: nil)
      invitation = Invitation.transaction do
        actor = lock_actor!(actor_membership, authorization)
        record = Invitation.lock.find_by!(id: invitation_id, organization_id: actor.organization_id)
        record.update!(status: "revoked", revoked_at: @clock.call) if record.pending?
        Audit.emit("invitation.revoked", outcome: "succeeded", operation: "revoke",
          organization_id: actor.organization_id,
          actor_membership_id: actor.id,
          target_type: "Invitation", target_id: record.id,
          metadata: { status: record.status })
        record
      end
      invitation
    rescue StandardError => error
      reject!("revoke", actor_membership, error)
    end

    def resend(actor_membership:, invitation_id:, authorization: nil)
      original = Invitation.transaction do
        actor = lock_actor!(actor_membership, authorization)
        record = Invitation.lock.find_by!(id: invitation_id, organization_id: actor.organization_id)
        raise InvitationAccessDenied if record.accepted?
        record
      end
      issued = @issuer.call(
        actor_membership: actor_membership,
        email: original.email,
        initial_role_key: original.initial_role_key,
        authorization: authorization
      )
      Audit.emit("invitation.resent", outcome: "succeeded", operation: "resend",
        organization_id: actor_membership.organization_id,
        actor_membership_id: actor_membership.id,
        target_type: "Invitation", target_id: issued.invitation.id,
        metadata: { status: issued.invitation.status })
      issued
    rescue StandardError => error
      reject!("resend", actor_membership, error)
    end

    private

    def lock_actor!(actor_membership, authorization)
      raise OrganizationAccessDenied unless actor_membership.is_a?(Membership)

      actor = Membership.lock.find(actor_membership.id)
      AuthorizeMembershipAccess.new.call(
        membership: actor, permission_key: "members.invite", authorization: authorization
      )
      actor
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end

    def reject!(operation, actor, error)
      public_error = error.is_a?(ActiveRecord::RecordNotFound) ? OrganizationAccessDenied.new : error
      Audit.emit(
        "invitation.#{operation}_rejected",
        outcome: "denied",
        operation: operation,
        reason_code: public_error.respond_to?(:reason_code) ? public_error.reason_code : nil,
        organization_id: actor&.organization_id,
        actor_membership_id: actor&.id,
        target_type: "Invitation"
      )
      raise public_error, cause: nil if public_error != error

      raise
    end
  end
end
