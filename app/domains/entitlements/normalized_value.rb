# frozen_string_literal: true

module Entitlements
  NormalizedValue = Data.define(:state, :stored_value, :value) do
    def initialize(state:, stored_value:, value:)
      super(
        state: state.to_s.freeze,
        stored_value: stored_value.is_a?(String) ? stored_value.dup.freeze : stored_value,
        value: value.is_a?(String) ? value.dup.freeze : value
      )
      freeze
    end
  end
end
