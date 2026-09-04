# frozen_string_literal: true

module Tenancy
  class ReviewInvitation
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(token:, user:)
      invitation = available_invitation(token)
      deny! unless Identity::Public.verified_email?(user: user, email: invitation.email)

      InvitationReview.new(
        id: invitation.id,
        organization_id: invitation.organization_id,
        organization_name: invitation.organization.name,
        email: invitation.email,
        expires_at: invitation.expires_at,
        initial_role_key: invitation.initial_role_key
      )
    end

    private

    def available_invitation(token)
      deny! unless InvitationToken.valid?(token)

      outcome = Invitation.transaction do
        invitation = Invitation.lock.find_by(token_digest: InvitationToken.digest(token))
        next [ :denied ] unless invitation&.pending?
        if invitation.expires_at <= @clock.call
          invitation.update!(status: "expired", expired_at: @clock.call)
          next [ :expired ]
        end
        [ :available, invitation ]
      end
      deny! unless outcome.first == :available

      outcome.last
    end

    def deny!
      raise InvitationAccessDenied
    end
  end
end
