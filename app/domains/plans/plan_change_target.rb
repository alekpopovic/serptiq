# frozen_string_literal: true

module Plans
  PlanChangeTarget = Data.define(:version, :direction, :effective_policy) do
    def initialize(version:, direction:, effective_policy:)
      super
      freeze
    end
  end
end
