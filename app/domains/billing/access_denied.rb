# frozen_string_literal: true

module Billing
  class AccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "billing_management_denied")
      super
    end
  end
end
