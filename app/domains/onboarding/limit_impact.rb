# frozen_string_literal: true

module Onboarding
  LimitImpact = Data.define(:entitlement_key, :state, :current, :limit, :unit) do
    def initialize(entitlement_key:, state:, current:, limit:, unit:)
      super(
        entitlement_key: entitlement_key.to_s.freeze,
        state: state.to_s.freeze,
        current: Integer(current),
        limit: limit.nil? ? nil : Integer(limit),
        unit: unit.to_s.freeze
      )
      freeze
    end

    def enabled?
      state == "enabled" && limit&.positive?
    end

    def available?
      enabled? && current < limit
    end

    def remaining
      return 0 unless enabled?

      [ limit - current, 0 ].max
    end
  end
end
