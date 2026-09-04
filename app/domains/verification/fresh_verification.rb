# frozen_string_literal: true

module Verification
  class FreshVerification
    def call(organization_id:, project_id:, property_id:, environment_id:, workload:, at: Time.current)
      environment = Properties::Public.environment_reference(
        organization_id: organization_id,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id
      )
      return unless environment&.active?

      challenge = Challenge.where(
        organization_id: organization_id,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id,
        state: "verified",
        bound_origin: environment.origin.origin
      ).order(verified_at: :desc, id: :desc).first
      return unless challenge && FreshnessPolicy.fresh?(challenge: challenge, workload: workload, at: at)

      VerificationReference.new(
        id: challenge.id,
        organization_id: challenge.organization_id,
        project_id: challenge.project_id,
        property_id: challenge.property_id,
        environment_id: challenge.environment_id,
        method: challenge.method,
        verified_at: challenge.verified_at,
        expires_at: challenge.expires_at
      )
    end
  end
end
