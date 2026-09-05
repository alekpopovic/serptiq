# frozen_string_literal: true

module Usage
  PROJECT_USAGE_READINESS_STATES = %w[available temporarily_reserved exhausted disabled unavailable].freeze

  ProjectUsageReadiness = Data.define(
    :project_id, :state, :used, :reserved, :limit, :remaining, :reset_at, :reason_code
  ) do
    def initialize(**attributes)
      normalized_state = attributes.fetch(:state).to_s
      raise ArgumentError, "project usage readiness state is invalid" unless
        PROJECT_USAGE_READINESS_STATES.include?(normalized_state)

      super(
        **attributes,
        project_id: attributes.fetch(:project_id).to_s.freeze,
        state: normalized_state.freeze,
        reason_code: attributes[:reason_code]&.to_s&.freeze
      )
      freeze
    end

    def exhausted?
      state.in?(%w[exhausted disabled])
    end

    def unavailable?
      state == "unavailable"
    end

    def temporarily_reserved?
      state == "temporarily_reserved"
    end
  end
end
