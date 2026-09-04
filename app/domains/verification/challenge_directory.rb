# frozen_string_literal: true

module Verification
  class ChallengeDirectory
    def initialize(access: Access.new, integration_permission: IntegrationPermission.new)
      @access = access
      @integration_permission = integration_permission
    end

    def latest(actor_membership:, project_id:, property_id:, environment_id:, challenge_id: nil)
      @access.call(
        actor_membership: actor_membership,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id,
        permission_key: "properties.verify"
      )
      scope = Challenge.where(
        organization_id: actor_membership&.organization_id,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id
      )
      challenge = challenge_id.present? ? scope.find_by(id: challenge_id) : scope.order(created_at: :desc).first
      raise AccessDenied if challenge_id.present? && !challenge
      return unless challenge
      if challenge.method == "search_console"
        @integration_permission.call(
          actor_membership: actor_membership,
          organization_id: challenge.organization_id
        )
      end

      ChallengeSummary.new(
        id: challenge.id,
        method: challenge.method,
        state: challenge.state,
        attempt_count: challenge.attempt_count,
        attempted_at: challenge.attempted_at,
        verified_at: challenge.verified_at,
        expires_at: challenge.expires_at,
        failure_category: challenge.failure_category,
        provider_property_identifier: challenge.provider_property_identifier,
        provider_permission_level: challenge.provider_permission_level,
        provider_checked_at: challenge.provider_checked_at,
        instructions: MethodCatalog.instructions(challenge),
        attempts: challenge.attempts.order(sequence: :desc).limit(10).to_a
      )
    end
  end
end
