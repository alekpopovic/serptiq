# frozen_string_literal: true

module Billing
  class ReconciliationJob < ApplicationJob
    class_attribute :reconciler_builder, default: -> { BillingReconciliationFactory.reconciler }

    runs_on :billing
    system_authorization :billing_reconciliation,
      reason: "compares an explicit tenant subscription with a bounded provider snapshot"

    def perform(reconciliation_run_id:)
      self.class.reconciler_builder.call.call(reconciliation_run_id: reconciliation_run_id)
    end
  end
end
