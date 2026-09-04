# frozen_string_literal: true

module Billing
  class PlanChangeRetry < Shared::Public::TransientInfrastructureError
    def initialize
      super(reason_code: "billing_plan_change_retry")
    end
  end
end
