# frozen_string_literal: true

module Tenancy
  class OwnershipTransferDenied < OrganizationAccessDenied
    def initialize(reason_code: "ownership_transfer_denied")
      super(reason_code: reason_code)
    end
  end
end
