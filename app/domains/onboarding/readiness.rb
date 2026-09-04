# frozen_string_literal: true

module Onboarding
  Readiness = Data.define(:items, :environment_id) do
    def initialize(items:, environment_id:)
      super(items: items.freeze, environment_id: environment_id&.to_s&.freeze)
      freeze
    end

    def ready?
      items.all?(&:ready?)
    end
  end
end
