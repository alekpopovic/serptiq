# frozen_string_literal: true

module Tenancy
  class InvalidMembershipTransition < Shared::Public::ConflictError
    def initialize(reason_code: "membership_transition_invalid")
      super(reason_code: reason_code)
    end
  end
end
