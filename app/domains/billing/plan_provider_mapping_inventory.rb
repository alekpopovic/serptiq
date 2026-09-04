# frozen_string_literal: true

module Billing
  class PlanProviderMappingInventory
    def call(active: nil)
      relation = PlanProviderMapping.order(:provider, :environment, :provider_variant_id)
      relation = relation.where(active: active) unless active.nil?
      relation.map do |mapping|
        PlanProviderMappingSummary.new(
          id: mapping.id,
          plan_version_id: mapping.plan_version_id,
          provider: mapping.provider,
          environment: mapping.environment,
          currency: mapping.currency,
          billing_interval: mapping.billing_interval,
          provider_variant_id: mapping.provider_variant_id,
          active: mapping.active
        )
      end.freeze
    end
  end
end
