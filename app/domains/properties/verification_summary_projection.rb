# frozen_string_literal: true

module Properties
  class VerificationSummaryProjection
    STATES = %w[unverified pending verified failed expired revoked].freeze

    def call(organization_id:, project_id:, property_id:, environment_id:, state:, verified_at: nil)
      normalized_state = state.to_s
      raise ArgumentError, "verification summary state is invalid" unless STATES.include?(normalized_state)

      changed = false
      Property.transaction do
        environment = Environment.find_by(
          id: environment_id,
          organization_id: organization_id,
          project_id: project_id,
          property_id: property_id,
          status: "active",
          primary: true
        )
        next unless environment

        property = Property.lock.find_by!(
          id: property_id, organization_id: organization_id, project_id: project_id
        )
        values = {
          verification_status: normalized_state,
          verified_at: normalized_state == "verified" ? verified_at : nil
        }
        changed = property.verification_status != values[:verification_status] ||
          property.verified_at != values[:verified_at]
        property.update!(values) if changed
      end
      changed
    end
  end
end
