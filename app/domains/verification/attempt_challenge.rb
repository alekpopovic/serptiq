# frozen_string_literal: true

module Verification
  class AttemptChallenge
    MAX_ATTEMPTS = 5
    MIN_ATTEMPT_INTERVAL = 30.seconds
    VERIFIED_TTL = 30.days

    def initialize(clock: -> { Time.current }, access: Access.new,
      registry: AdapterRegistry.unconfigured)
      @clock = clock
      @access = access
      @registry = registry
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, challenge_id:)
      context = @access.call(
        actor_membership: actor_membership,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id,
        permission_key: "properties.verify"
      )
      reservation, terminal_result, events = reserve_attempt(
        actor_membership: actor_membership,
        context: context,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id,
        challenge_id: challenge_id
      )
      events.each { |event| ChallengeEvent.enqueue(event) }
      return terminal_result if terminal_result

      adapter_result = safely_verify(reservation)
      result, event = finalize_attempt(
        actor_membership: actor_membership,
        context: context,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id,
        reservation: reservation,
        adapter_result: adapter_result
      )
      ChallengeEvent.enqueue(event) if event
      result
    rescue RateLimited
      if defined?(context) && context
        challenge = Challenge.find_by(
          id: challenge_id,
          organization_id: actor_membership&.organization_id,
          project_id: project_id,
          property_id: property_id,
          environment_id: environment_id
        )
        ChallengeAudit.record!(
          action: "verification.attempt_failed",
          challenge: challenge,
          actor_membership_id: context.actor_membership_id,
          operation: "rate_limit",
          failure_category: "rate_limited"
        ) if challenge
      end
      raise
    end

    private

    def reserve_attempt(actor_membership:, context:, project_id:, property_id:, environment_id:,
      challenge_id:)
      reservation = nil
      terminal = nil
      events = []
      Challenge.transaction do
        challenge = scoped_challenge!(
          actor_membership, project_id, property_id, environment_id, challenge_id
        )
        now = @clock.call
        if (challenge.pending? || challenge.verified?) && challenge.expires_at <= now
          challenge.update!(state: "expired", expired_at: now)
          project_summary(challenge, state: "expired")
          ChallengeAudit.record!(
            action: "verification.expired",
            challenge: challenge,
            actor_membership_id: context.actor_membership_id,
            operation: "expire"
          )
          events << ChallengeEvent.record!(
            challenge: challenge,
            event_type: "verification.expired",
            actor_membership_id: context.actor_membership_id,
            occurred_at: now
          )
          terminal = ChallengeResult.new(challenge: challenge, changed: true)
          next
        end
        if challenge.verified?
          terminal = ChallengeResult.new(challenge: challenge, changed: false)
          next
        end
        raise Conflict.new(reason_code: "verification_not_pending") unless challenge.pending?
        enforce_attempt_interval!(challenge, now, context)

        sequence = challenge.attempt_count + 1
        challenge.update!(attempt_count: sequence, attempted_at: now)
        reservation = AttemptReservation.new(
          challenge_id: challenge.id,
          sequence: sequence,
          expected_value: ChallengeToken.value_for(challenge),
          attempted_at: now
        )
      end
      [ reservation, terminal, events ]
    end

    def safely_verify(reservation)
      challenge = Challenge.find(reservation.challenge_id)
      result = @registry.fetch(challenge.method).verify(
        challenge: challenge,
        expected_value: reservation.expected_value
      )
      return result if result.is_a?(AdapterResult)

      AdapterResult.new(verified: false, failure_category: "malformed_response")
    rescue StandardError
      AdapterResult.new(verified: false, failure_category: "provider_unavailable")
    end

    def finalize_attempt(actor_membership:, context:, project_id:, property_id:, environment_id:,
      reservation:, adapter_result:)
      result = nil
      event = Challenge.transaction do
        challenge = scoped_challenge!(
          actor_membership, project_id, property_id, environment_id, reservation.challenge_id
        )
        unless challenge.pending?
          ChallengeAudit.record!(
            action: "verification.attempt_failed",
            challenge: challenge,
            actor_membership_id: context.actor_membership_id,
            operation: "attempt_ignored",
            failure_category: adapter_result.failure_category || "proof_mismatch"
          )
          result = ChallengeResult.new(challenge: challenge, changed: false)
          next
        end

        now = @clock.call
        Attempt.create!(
          organization_id: challenge.organization_id,
          project_id: challenge.project_id,
          property_id: challenge.property_id,
          environment_id: challenge.environment_id,
          domain_verification_id: challenge.id,
          sequence: reservation.sequence,
          outcome: adapter_result.verified? ? "verified" : "failed",
          failure_category: adapter_result.failure_category,
          evidence: adapter_result.evidence,
          attempted_at: reservation.attempted_at,
          created_at: now
        )
        if adapter_result.verified?
          challenge.update!(
            state: "verified", verified_at: now, expires_at: now + VERIFIED_TTL,
            evidence: adapter_result.evidence
          )
          project_summary(challenge, state: "verified", verified_at: now)
          action = "verification.succeeded"
          operation = "verify"
        else
          attributes = { evidence: adapter_result.evidence }
          if challenge.attempt_count >= MAX_ATTEMPTS
            attributes.merge!(
              state: "failed", failed_at: now, failure_category: adapter_result.failure_category
            )
          end
          challenge.update!(attributes)
          project_summary(challenge, state: "failed") if challenge.failed?
          action = "verification.attempt_failed"
          operation = "attempt"
        end
        ChallengeAudit.record!(
          action: action,
          challenge: challenge,
          actor_membership_id: context.actor_membership_id,
          operation: operation,
          failure_category: adapter_result.failure_category
        )
        result = ChallengeResult.new(challenge: challenge, changed: true)
        ChallengeEvent.record!(
          challenge: challenge,
          event_type: action,
          actor_membership_id: context.actor_membership_id,
          occurred_at: now
        )
      end
      [ result, event ]
    end

    def enforce_attempt_interval!(challenge, now, _context)
      return unless challenge.attempted_at && challenge.attempted_at + MIN_ATTEMPT_INTERVAL > now

      retry_after = (challenge.attempted_at + MIN_ATTEMPT_INTERVAL - now).ceil
      raise RateLimited.new(retry_after: retry_after)
    end

    def project_summary(challenge, state:, verified_at: nil)
      Properties::Public.apply_verification_summary(
        organization_id: challenge.organization_id,
        project_id: challenge.project_id,
        property_id: challenge.property_id,
        environment_id: challenge.environment_id,
        state: state,
        verified_at: verified_at
      )
    end

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
