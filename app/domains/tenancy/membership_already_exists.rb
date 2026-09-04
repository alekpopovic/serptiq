# frozen_string_literal: true

module Tenancy
  class MembershipAlreadyExists < Shared::Public::ConflictError
    def initialize(reason_code: "membership_already_exists")
      super(reason_code: reason_code)
    end
  end
end
