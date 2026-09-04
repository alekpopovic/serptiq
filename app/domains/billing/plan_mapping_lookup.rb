# frozen_string_literal: true

module Billing
  class PlanMappingLookup
    def call(plan_version_id:, provider:, environment:, currency:, billing_interval:)
      mapping = PlanProviderMapping.find_by(
        plan_version_id: plan_version_id,
        provider: provider.to_s,
        environment: environment.to_s,
        currency: currency.to_s,
        billing_interval: billing_interval.to_s,
        active: true
      )
      raise ProviderMappingMissing.new(reason_code: "billing_plan_mapping_missing") unless mapping

      PlanMapping.new(
        plan_version_id: mapping.plan_version_id,
        provider: mapping.provider,
        environment: mapping.environment,
        currency: mapping.currency,
        billing_interval: mapping.billing_interval,
        variant_reference: mapping.provider_variant_id
      )
    end
  end
end
