# frozen_string_literal: true

module Projects
  DASHBOARD_CHECKLIST_STATES = %w[ready action_required unavailable restricted].freeze

  DashboardChecklistItem = Data.define(:key, :state, :title, :detail) do
    def initialize(key:, state:, title:, detail:)
      normalized_state = state.to_s
      raise ArgumentError, "dashboard checklist state is invalid" unless
        DASHBOARD_CHECKLIST_STATES.include?(normalized_state)

      super(
        key: key.to_s.freeze,
        state: normalized_state.freeze,
        title: title.to_s.freeze,
        detail: detail.to_s.freeze
      )
      freeze
    end

    def ready?
      state == "ready"
    end
  end
end
