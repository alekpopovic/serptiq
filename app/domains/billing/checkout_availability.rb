# frozen_string_literal: true

module Billing
  class CheckoutAvailability
    def initialize(settings: Rails.application.config.x.searchops, environment: Rails.env.to_s)
      @settings = settings
      @environment = environment.to_s
    end

    def call(plan_version_id:, currency:, billing_interval:)
      provider = @settings.fetch(:billing_provider)
      return false if provider == "disabled"

      PlanProviderMapping.exists?(
        plan_version_id: plan_version_id,
        provider: provider,
        environment: @environment,
        currency: currency.to_s,
        billing_interval: billing_interval.to_s,
        active: true
      )
    end
  end
end
