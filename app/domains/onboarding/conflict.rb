# frozen_string_literal: true

module Onboarding
  class Conflict < Shared::Public::ConflictError
    def initialize(reason_code: "onboarding_state_conflict")
      super(reason_code: reason_code)
    end
  end
end
