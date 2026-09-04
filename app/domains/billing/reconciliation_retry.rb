# frozen_string_literal: true

module Billing
  class ReconciliationRetry < Shared::Public::TransientInfrastructureError
    def initialize
      super(reason_code: "billing_reconciliation_retry")
    end
  end
end
