# frozen_string_literal: true

module Projects
  DashboardAction = Data.define(:allowed, :reason_code, :explanation) do
    def initialize(allowed:, reason_code:, explanation:)
      super(
        allowed: !!allowed,
        reason_code: reason_code.to_s.freeze,
        explanation: explanation.to_s.freeze
      )
      freeze
    end

    def allowed?
      allowed
    end
  end
end
