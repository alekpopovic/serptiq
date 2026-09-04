# frozen_string_literal: true

module Billing
  class SubscriptionConflict < Shared::Public::ConflictError
    def initialize(reason_code: "subscription_reference_conflict")
      super
    end
  end
end
