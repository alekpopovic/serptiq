# frozen_string_literal: true

module Tenancy
  class AcceptInvitation
    def initialize(clock: -> { Time.current }, rate_limiter: InvitationRateLimiter.new)
      @clock = clock
      @rate_limiter = rate_limiter
    end

    def call(token:, user:, rate_limit_key:)
      @rate_limiter.consume!(scope: "accept_ip", key: rate_limit_key)
      deny! unless InvitationToken.valid?(token) && Identity::Public.active_user?(user)

      outcome = Invitation.transaction do
        now = @clock.call
        invitation = Invitation.lock.find_by(token_digest: InvitationToken.digest(token))
        deny! unless invitation&.pending?
        if invitation.expires_at <= now
          invitation.update!(status: "expired", expired_at: now)
          next [ :denied ]
        end
        deny! unless Identity::Public.verified_email?(user: user, email: invitation.email)

        membership = Membership.lock.find_by(organization_id: invitation.organization_id, user_id: user.id)
        membership = activate_membership!(membership, invitation, user, now)
        invitation.update!(
          status: "accepted",
          accepted_at: now,
          accepted_by_membership_id: membership.id
        )
        [ :accepted, membership ]
      end
      deny! unless outcome.first == :accepted

      membership = outcome.last
      Audit.emit(
        "invitation.accepted",
        outcome: "succeeded",
        operation: "accept",
        subject_membership_id: membership.id
      )
      membership
    rescue StandardError => error
      Audit.emit(
        "invitation.accept_rejected",
        outcome: "denied",
        operation: "accept",
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : nil
      )
      raise
    end

    private

    def activate_membership!(membership, invitation, user, now)
      if membership.nil?
        return Membership.create!(
          organization_id: invitation.organization_id,
          user_id: user.id,
          display_name: user.display_name,
          status: "active",
          accepted_at: now
        )
      end

      raise RemovedMembershipReactivationDenied if membership.removed?

      membership.status = "active"
      membership.accepted_at ||= now
      membership.suspended_at = nil
      membership.save!
      membership
    end

    def deny!
      raise InvitationAccessDenied
    end
  end
end
