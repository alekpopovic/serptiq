# frozen_string_literal: true

module Verification
  class IssueChallenge
    PENDING_TTL = 24.hours

    def initialize(clock: -> { Time.current }, id_generator: -> { SecureRandom.uuid }, access: Access.new)
      @clock = clock
      @id_generator = id_generator
      @access = access
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, method:)
      normalized_method = method.to_s
      raise ArgumentError, "unsupported verification method" unless Challenge::METHODS.include?(normalized_method)

      context = @access.call(
        actor_membership: actor_membership,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id,
        permission_key: "properties.verify"
      )
      raise Conflict.new(reason_code: "verification_resource_inactive") unless
        context.project.active? && context.property.active? && context.environment.active?

      challenge = nil
      events = []
      now = @clock.call
      Challenge.transaction do
        environment = context.environment
        Challenge.current.where(
          organization_id: environment.organization_id,
          environment_id: environment.id
        ).lock.each do |current|
          current.update!(state: "revoked", revoked_at: now)
          ChallengeAudit.record!(
            action: "verification.revoked",
            challenge: current,
            actor_membership_id: context.actor_membership_id,
            operation: "supersede"
          )
          events << ChallengeEvent.record!(
            challenge: current,
            event_type: "verification.revoked",
            actor_membership_id: context.actor_membership_id,
            occurred_at: now
          )
        end

        origin = environment.origin
        challenge = Challenge.new(
          id: @id_generator.call,
          organization_id: environment.organization_id,
          project_id: environment.project_id,
          property_id: environment.property_id,
          environment_id: environment.id,
          issued_by_membership_id: context.actor_membership_id,
          method: normalized_method,
          expected_location: MethodCatalog.expected_location(method: normalized_method, origin: origin),
          bound_origin: origin.origin,
          state: "pending",
          attempt_count: 0,
          expires_at: now + PENDING_TTL,
          evidence: {},
          created_at: now,
          updated_at: now
        )
        challenge.challenge_digest = ChallengeToken.digest(ChallengeToken.value_for(challenge))
        challenge.save!
        Properties::Public.apply_verification_summary(
          organization_id: challenge.organization_id,
          project_id: challenge.project_id,
          property_id: challenge.property_id,
          environment_id: challenge.environment_id,
          state: "pending"
        )
        ChallengeAudit.record!(
          action: "verification.issued",
          challenge: challenge,
          actor_membership_id: context.actor_membership_id,
          operation: "issue"
        )
        events << ChallengeEvent.record!(
          challenge: challenge,
          event_type: "verification.issued",
          actor_membership_id: context.actor_membership_id,
          occurred_at: now
        )
      end
      events.each { |event| ChallengeEvent.enqueue(event) }
      IssuedChallenge.new(challenge: challenge, instructions: MethodCatalog.instructions(challenge))
    end
  end
end
