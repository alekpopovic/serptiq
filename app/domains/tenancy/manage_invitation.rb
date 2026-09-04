# frozen_string_literal: true

module Tenancy
  class ManageInvitation
    def initialize(clock: -> { Time.current }, issuer: nil)
      @clock = clock
      @issuer = issuer || IssueInvitation.new(clock: clock)
    end

    def revoke(actor_membership:, invitation_id:)
      invitation = Invitation.transaction do
        actor = lock_owner!(actor_membership)
        record = Invitation.lock.find_by!(id: invitation_id, organization_id: actor.organization_id)
        record.update!(status: "revoked", revoked_at: @clock.call) if record.pending?
        record
      end
      Audit.emit("invitation.revoked", outcome: "succeeded", operation: "revoke",
        actor_membership_id: actor_membership.id)
      invitation
    rescue StandardError => error
      reject!("revoke", actor_membership, error)
    end

    def resend(actor_membership:, invitation_id:)
      original = Invitation.transaction do
        actor = lock_owner!(actor_membership)
        record = Invitation.lock.find_by!(id: invitation_id, organization_id: actor.organization_id)
        raise InvitationAccessDenied if record.accepted?
        record
      end
      issued = @issuer.call(
        actor_membership: actor_membership,
        email: original.email,
        initial_role_key: original.initial_role_key
      )
      Audit.emit("invitation.resent", outcome: "succeeded", operation: "resend",
        actor_membership_id: actor_membership.id)
      issued
    rescue StandardError => error
      reject!("resend", actor_membership, error)
    end

    private

    def lock_owner!(actor_membership)
      raise OrganizationAccessDenied unless actor_membership.is_a?(Membership)

      actor = Membership.lock.find(actor_membership.id)
      AuthorizeOrganizationOwner.new.call(membership: actor)
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
        actor_membership_id: actor&.id
      )
      raise public_error, cause: nil if public_error != error

      raise
    end
  end
end
