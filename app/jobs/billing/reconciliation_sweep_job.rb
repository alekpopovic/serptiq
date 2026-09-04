# frozen_string_literal: true

module Billing
  class ReconciliationSweepJob < ApplicationJob
    class_attribute :scheduler_builder, default: -> { BillingReconciliationFactory.scheduler }

    runs_on :billing
    system_authorization :billing_reconciliation_sweep,
      reason: "schedules bounded provider checks for active and recently ended subscriptions"

    def perform
      self.class.scheduler_builder.call.call
    end
  end
end
