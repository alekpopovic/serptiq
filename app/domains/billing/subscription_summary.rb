# frozen_string_literal: true

module Billing
  SubscriptionSummary = Data.define(
    :id, :organization_id, :plan_version_id, :status, :access_state, :billing_interval,
    :plan_display_name, :currency, :pricing_kind, :price_cents, :started_at, :ended_at,
    :current_period_ends_at, :cancel_at_period_end, :provider_backed
  ) do
    def initialize(**attributes)
      %i[
        id organization_id plan_version_id status access_state billing_interval
        plan_display_name currency pricing_kind
      ].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end

    def full_access?
      access_state == "full"
    end

    def provider_backed?
      provider_backed
    end
  end
end
