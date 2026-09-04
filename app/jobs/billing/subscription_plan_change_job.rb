# frozen_string_literal: true

module Billing
  class SubscriptionPlanChangeJob < ApplicationJob
    class_attribute :submitter_builder, default: -> { BillingPlanChangeFactory.submitter }

    runs_on :billing
    system_authorization :billing_subscription_plan_change,
      reason: "submits a tenant-bound durable plan change to the configured billing provider"

    def perform(organization_id:, subscription_change_id:)
      self.class.submitter_builder.call.call(
        organization_id: organization_id,
        subscription_change_id: subscription_change_id
      )
    end
  end
end
