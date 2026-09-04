# frozen_string_literal: true

module Billing
  class LemonSqueezyPlanMappingLookup
    PROVIDER = "lemon_squeezy"

    def initialize(environment:, store_reference:)
      @environment = ValueNormalization.string!(environment, name: "environment", maximum: 16)
      @store_reference = provider_reference(store_reference, "store reference")
    end

    def call(variant_reference:, product_reference:, store_reference:)
      variant = provider_reference(variant_reference, "variant reference")
      product = provider_reference(product_reference, "product reference")
      store = provider_reference(store_reference, "store reference")
      raise ProviderMappingMissing.new(reason_code: "billing_provider_store_mismatch") unless store == @store_reference

      mapping = PlanProviderMapping.find_by(
        provider: PROVIDER,
        environment: @environment,
        provider_store_id: store,
        provider_product_id: product,
        provider_variant_id: variant,
        active: true
      )
      raise ProviderMappingMissing.new(reason_code: "billing_plan_mapping_missing") unless mapping

      PlanMapping.new(
        plan_version_id: mapping.plan_version_id,
        provider: mapping.provider,
        environment: mapping.environment,
        currency: mapping.currency,
        billing_interval: mapping.billing_interval,
        store_reference: mapping.provider_store_id,
        product_reference: mapping.provider_product_id,
        variant_reference: mapping.provider_variant_id
      )
    end

    private

    def provider_reference(value, name)
      ValueNormalization.string!(
        value, name: name, maximum: 128, pattern: PlanProviderMapping::LEMON_SQUEEZY_REFERENCE_PATTERN
      )
    end
  end
end
