# frozen_string_literal: true

module Tenancy
  class OwnershipTransferConfirmationInvalid < Shared::Public::ValidationError
    def initialize(reason_code: "ownership_transfer_confirmation_invalid")
      super(reason_code: reason_code)
    end
  end
end
