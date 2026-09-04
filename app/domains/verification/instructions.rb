# frozen_string_literal: true

module Verification
  Instructions = Data.define(:method, :label, :location, :value, :steps) do
    def initialize(method:, label:, location:, value:, steps:)
      normalized_steps = Array(steps).map { |step| step.to_s.freeze }.freeze
      super(
        method: method.to_s.freeze,
        label: label.to_s.freeze,
        location: location.to_s.freeze,
        value: value.to_s.freeze,
        steps: normalized_steps
      )
      freeze
    end
  end
end
