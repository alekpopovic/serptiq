# frozen_string_literal: true

module Verification
  class RevokeChallenge
    def initialize(clock: -> { Time.current }, access: Access.new)
      @clock = clock
      @access = access
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, challenge_id:)
      context = @access.call(
        actor_membership: actor_membership,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id,
        permission_key: "properties.verify"
      )
      result = nil
      event = Challenge.transaction do
        challenge = scoped_challenge!(actor_membership, project_id, property_id, environment_id, challenge_id)
        if challenge.revoked?
          result = ChallengeResult.new(challenge: challenge, changed: false)
          next
        end
        raise Conflict unless challenge.pending? || challenge.verified?

        now = @clock.call
        challenge.update!(state: "revoked", revoked_at: now)
        Properties::Public.apply_verification_summary(
          organization_id: challenge.organization_id,
          project_id: challenge.project_id,
          property_id: challenge.property_id,
          environment_id: challenge.environment_id,
          state: "revoked"
        )
        ChallengeAudit.record!(
          action: "verification.revoked",
          challenge: challenge,
          actor_membership_id: context.actor_membership_id,
          operation: "revoke"
        )
        result = ChallengeResult.new(challenge: challenge, changed: true)
        ChallengeEvent.record!(
          challenge: challenge,
          event_type: "verification.revoked",
          actor_membership_id: context.actor_membership_id,
          occurred_at: now
        )
      end
      ChallengeEvent.enqueue(event) if event
      result
    end

    private

    def scoped_challenge!(actor_membership, project_id, property_id, environment_id, challenge_id)
      Challenge.lock.find_by!(
        id: challenge_id,
        organization_id: actor_membership&.organization_id,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id
      )
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied, cause: nil
    end
  end
end
