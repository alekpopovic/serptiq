# frozen_string_literal: true

module Verification
  class Conflict < Shared::Public::ConflictError
    def initialize(reason_code: "verification_state_conflict")
      super(reason_code: reason_code)
    end
  end
end
