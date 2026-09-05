# frozen_string_literal: true

module Crawling
  SCAN_OBSERVATION_STATES = %w[unavailable loading failed stale no_data ready].freeze

  ScanObservation = Data.define(:kind, :state, :label, :detail, :count, :observed_at) do
    def initialize(state:, label:, detail:, count: nil, observed_at: nil)
      normalized = state.to_s
      raise ArgumentError, "scan observation state is invalid" unless
        SCAN_OBSERVATION_STATES.include?(normalized)

      super(
        kind: "scan",
        state: normalized.freeze,
        label: label.to_s.freeze,
        detail: detail.to_s.freeze,
        count: count.nil? ? nil : Integer(count),
        observed_at: observed_at
      )
      freeze
    end

    SCAN_OBSERVATION_STATES.each { |value| define_method("#{value}?") { state == value } }
  end
end
