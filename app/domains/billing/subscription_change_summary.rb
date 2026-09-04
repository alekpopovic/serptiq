# frozen_string_literal: true

module Billing
  SubscriptionChangeSummary = Data.define(
    :id, :organization_id, :subscription_id, :from_plan_version_id, :target_plan_version_id,
    :target_billing_interval, :direction, :effective_policy, :state, :effective_at
  ) do
    def initialize(**attributes)
      %i[
        id organization_id subscription_id from_plan_version_id target_plan_version_id
        target_billing_interval direction effective_policy state
      ].each { |name| attributes[name] = attributes.fetch(name).to_s.freeze }
      super(**attributes)
      freeze
    end
  end
end
