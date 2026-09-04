# frozen_string_literal: true

module Verification
  class IssueChallenge
    PENDING_TTL = 24.hours

    def initialize(clock: -> { Time.current }, id_generator: -> { SecureRandom.uuid }, access: Access.new,
      integration_permission: IntegrationPermission.new, selection_token: SearchConsoleSelectionToken.new,
      selection_resolver: nil)
      @clock = clock
      @id_generator = id_generator
      @access = access
      @integration_permission = integration_permission
      @selection_token = selection_token
      @selection_resolver = selection_resolver
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, method:,
      search_console_selection: nil)
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
      selection = resolve_search_console_selection(
        method: normalized_method,
        actor_membership: actor_membership,
        context: context,
        selection_token: search_console_selection
      )

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
        if selection
          challenge.assign_attributes(
            integration_connection_id: selection.connection_id,
            provider_property_identifier: selection.external_property_identifier,
            provider_property_type: selection.property_type,
            provider_permission_level: selection.permission_level,
            provider_checked_at: selection.checked_at,
            connection_revision: selection.connection_revision
          )
        end
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

    private

    def resolve_search_console_selection(method:, actor_membership:, context:, selection_token:)
      return unless method == "search_console"

      @integration_permission.call(
        actor_membership: actor_membership,
        organization_id: context.environment.organization_id
      )
      raise SearchConsoleSelectionError, "provider_outage" unless @selection_resolver

      connection_id, identifier = @selection_token.verify(selection_token)
      @selection_resolver.call(
        organization_id: context.environment.organization_id,
        connection_id: connection_id,
        external_property_identifier: identifier,
        origin: context.environment.origin.origin
      )
    end
  end
end
