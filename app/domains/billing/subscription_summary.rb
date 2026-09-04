# frozen_string_literal: true

module Billing
  SubscriptionSummary = Data.define(
    :id, :organization_id, :plan_version_id, :status, :billing_interval,
    :plan_display_name, :currency, :pricing_kind, :price_cents, :started_at, :ended_at
  ) do
    def initialize(**attributes)
      %i[id organization_id plan_version_id status billing_interval plan_display_name currency pricing_kind].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end
  end
end
