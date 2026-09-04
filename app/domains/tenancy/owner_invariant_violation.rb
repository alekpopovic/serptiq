# frozen_string_literal: true

module Tenancy
  class OwnerInvariantViolation < Shared::Public::ConflictError
    def initialize(reason_code: "organization_owner_inconsistent")
      super(reason_code: reason_code)
    end
  end
end
