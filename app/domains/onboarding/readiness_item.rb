# frozen_string_literal: true

module Onboarding
  ReadinessItem = Data.define(:key, :label, :ready, :detail) do
    def initialize(key:, label:, ready:, detail:)
      super(
        key: key.to_s.freeze,
        label: label.to_s.freeze,
        ready: !!ready,
        detail: detail.to_s.freeze
      )
      freeze
    end

    def ready?
      ready
    end
  end
end
