# frozen_string_literal: true

module Integrations
  DASHBOARD_READINESS_STATES = %w[connected degraded reauthorization_required not_connected].freeze

  DashboardReadiness = Data.define(:state, :label, :detail, :connection_count) do
    def initialize(state:, label:, detail:, connection_count:)
      normalized_state = state.to_s
      raise ArgumentError, "integration readiness state is invalid" unless
        DASHBOARD_READINESS_STATES.include?(normalized_state)

      super(
        state: normalized_state.freeze,
        label: label.to_s.freeze,
        detail: detail.to_s.freeze,
        connection_count: Integer(connection_count)
      )
      freeze
    end
  end
end
