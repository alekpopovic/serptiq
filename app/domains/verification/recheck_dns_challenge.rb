# frozen_string_literal: true

module Verification
  class RecheckDnsChallenge
    VERIFIED_TTL = AttemptChallenge::VERIFIED_TTL

    def initialize(adapter:, clock: -> { Time.current })
      raise ArgumentError, "DNS recheck requires the DNS TXT adapter" unless
        adapter.respond_to?(:method) && adapter.method == "dns_txt" && adapter.respond_to?(:verify)

      @adapter = adapter
      @clock = clock
    end

    def call(organization_id:, challenge_id:)
      challenge, reservation = reserve(organization_id: organization_id, challenge_id: challenge_id)
      return ChallengeResult.new(challenge: challenge, changed: false) unless reservation

      adapter_result = safely_verify(challenge, reservation)
      finalize(
        organization_id: organization_id,
        challenge_id: challenge_id,
        reservation: reservation,
        adapter_result: adapter_result
      )
    end

    private

    def reserve(organization_id:, challenge_id:)
      Challenge.transaction do
        challenge = Challenge.lock.find_by(id: challenge_id, organization_id: organization_id)
        return [ nil, nil ] unless challenge

        at = @clock.call
        environment = exact_environment(challenge)
        return [ challenge, nil ] unless environment && FreshnessPolicy.dns_recheck_due?(
          challenge: challenge, at: at
        )

        sequence = challenge.attempt_count + 1
        challenge.update!(attempt_count: sequence, attempted_at: at)
        reservation = AttemptReservation.new(
          challenge_id: challenge.id,
          sequence: sequence,
          expected_value: ChallengeToken.value_for(challenge),
          attempted_at: at
        )
        [ challenge, reservation ]
      end
    end

    def safely_verify(challenge, reservation)
      result = @adapter.verify(challenge: challenge, expected_value: reservation.expected_value)
      return result if result.is_a?(AdapterResult)

      AdapterResult.new(verified: false, failure_category: "malformed_response")
    rescue StandardError
      AdapterResult.new(verified: false, failure_category: "dns_transient_failure")
    end

    def finalize(organization_id:, challenge_id:, reservation:, adapter_result:)
      result = nil
      event = Challenge.transaction do
        challenge = Challenge.lock.find_by(id: challenge_id, organization_id: organization_id)
        unless challenge&.verified? && challenge.method == "dns_txt" && exact_environment(challenge)
          result = ChallengeResult.new(challenge: challenge, changed: false)
          next
        end

        at = @clock.call
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
          created_at: at
        )
        if adapter_result.verified?
          challenge.update!(verified_at: at, expires_at: at + VERIFIED_TTL, evidence: adapter_result.evidence)
          Properties::Public.apply_verification_summary(
            organization_id: challenge.organization_id,
            project_id: challenge.project_id,
            property_id: challenge.property_id,
            environment_id: challenge.environment_id,
            state: "verified",
            verified_at: at
          )
          action = "verification.recheck_succeeded"
        else
          action = "verification.recheck_failed"
        end
        ChallengeAudit.record!(
          action: action,
          challenge: challenge,
          actor_membership_id: nil,
          operation: "dns_recheck",
          failure_category: adapter_result.failure_category
        )
        result = ChallengeResult.new(challenge: challenge, changed: true)
        ChallengeEvent.record!(
          challenge: challenge,
          event_type: action,
          actor_membership_id: nil,
          occurred_at: at
        )
      end
      ChallengeEvent.enqueue(event) if event
      result
    end

    def exact_environment(challenge)
      environment = Properties::Public.environment_reference(
        organization_id: challenge.organization_id,
        project_id: challenge.project_id,
        property_id: challenge.property_id,
        environment_id: challenge.environment_id
      )
      environment if environment&.active? && environment.origin.origin == challenge.bound_origin
    end
  end
end
