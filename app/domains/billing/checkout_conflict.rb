# frozen_string_literal: true

module Billing
  class CheckoutConflict < Shared::Public::ConflictError
    def initialize(reason_code: "billing_checkout_conflict")
      super
    end
  end
end
