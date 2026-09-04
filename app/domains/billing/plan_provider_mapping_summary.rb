# frozen_string_literal: true

module Billing
  PlanProviderMappingSummary = Data.define(
    :id, :plan_version_id, :provider, :environment, :currency,
    :billing_interval, :provider_variant_id, :active
  ) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end

    def active?
      active
    end
  end
end
