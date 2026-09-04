# frozen_string_literal: true

module Tenancy
  class LastOwnerConflict < Shared::Public::ConflictError
    def initialize(reason_code: "last_owner_transfer_required")
      super(reason_code: reason_code)
    end
  end
end
