# frozen_string_literal: true

module Tenancy
  class RemovedMembershipReactivationDenied < Shared::Public::ConflictError
    def initialize(reason_code: "removed_membership_reactivation_denied")
      super(reason_code: reason_code)
    end
  end
end
