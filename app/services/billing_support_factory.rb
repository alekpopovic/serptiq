# frozen_string_literal: true

class BillingSupportFactory
  class << self
    def replayer
      Billing::ReplayWebhookEvent.new(auditor: Auditing::Public)
    end

    def reconciliation_requester
      BillingReconciliationFactory.requester
    end
  end
end
