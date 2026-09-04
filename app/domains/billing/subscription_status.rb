# frozen_string_literal: true

module Billing
  SubscriptionStatus = Data.define(
    :subscription_id, :status, :access_state, :label, :message, :remediation,
    :effective_at, :provider_reported_at, :plan_change
  ) do
    def initialize(**attributes)
      %i[subscription_id status access_state label message remediation].each do |name|
        attributes[name] = attributes.fetch(name)&.to_s&.freeze
      end
      super(**attributes)
      freeze
    end
  end
end
