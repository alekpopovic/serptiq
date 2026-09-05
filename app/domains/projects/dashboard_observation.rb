# frozen_string_literal: true

module Projects
  DASHBOARD_OBSERVATION_STATES = %w[unavailable loading failed stale no_data ready].freeze
  DASHBOARD_OBSERVATION_KINDS = %w[scan findings properties].freeze
  DASHBOARD_OBSERVATION_COPY = {
    "unavailable" => [ "Unavailable", "This observation is not available for the current access or resource state." ],
    "loading" => [ "Loading", "The latest observation is still being prepared." ],
    "failed" => [ "Failed", "The latest observation failed; retained historical evidence is unchanged." ],
    "stale" => [ "Stale", "The latest observation is older than the configured freshness policy." ],
    "no_data" => [ "No data", "No completed observation exists yet." ],
    "ready" => [ "Observed", "This value comes from persisted product evidence." ]
  }.freeze

  DashboardObservation = Data.define(:kind, :state, :label, :detail, :count, :observed_at) do
    def self.states
      DASHBOARD_OBSERVATION_STATES
    end

    def initialize(kind:, state:, label: nil, detail: nil, count: nil, observed_at: nil)
      normalized_kind = kind.to_s
      normalized_state = state.to_s
      raise ArgumentError, "dashboard observation kind is invalid" unless
        DASHBOARD_OBSERVATION_KINDS.include?(normalized_kind)
      raise ArgumentError, "dashboard observation state is invalid" unless
        DASHBOARD_OBSERVATION_STATES.include?(normalized_state)

      default_label, default_detail = DASHBOARD_OBSERVATION_COPY.fetch(normalized_state)
      normalized_count = count.nil? ? nil : Integer(count)
      raise ArgumentError, "dashboard observation count is invalid" if normalized_count&.negative?

      super(
        kind: normalized_kind.freeze,
        state: normalized_state.freeze,
        label: (label || default_label).to_s.freeze,
        detail: (detail || default_detail).to_s.freeze,
        count: normalized_count,
        observed_at: observed_at
      )
      freeze
    end

    DASHBOARD_OBSERVATION_STATES.each { |value| define_method("#{value}?") { state == value } }
  end
end
