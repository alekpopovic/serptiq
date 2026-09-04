# frozen_string_literal: true

module Billing
  PlanMapping = Data.define(
    :plan_version_id, :provider, :environment, :currency, :billing_interval,
    :store_reference, :product_reference, :variant_reference
  ) do
    def initialize(plan_version_id:, provider:, environment:, currency:, billing_interval:, variant_reference:,
      store_reference: nil, product_reference: nil)
      coordinates = [ store_reference, product_reference ]
      unless coordinates.all?(&:nil?) || coordinates.none?(&:nil?)
        raise ArgumentError, "provider catalog coordinates are incomplete"
      end

      super(
        plan_version_id: ValueNormalization.uuid!(plan_version_id, name: "plan version"),
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        environment: ValueNormalization.string!(environment, name: "environment", maximum: 16),
        currency: ValueNormalization.string!(currency, name: "currency", maximum: 3, pattern: /\A[A-Z]{3}\z/),
        billing_interval: ValueNormalization.string!(
          billing_interval, name: "billing interval", maximum: 16, pattern: /\A(?:monthly|annual)\z/
        ),
        store_reference: provider_reference(store_reference, "store reference"),
        product_reference: provider_reference(product_reference, "product reference"),
        variant_reference: ValueNormalization.string!(
          variant_reference, name: "variant reference", maximum: 191,
          pattern: ValueNormalization::REFERENCE_PATTERN
        )
      )
      freeze
    end

    def as_json(*)
      {
        plan_version_id: plan_version_id,
        provider: provider,
        environment: environment,
        currency: currency,
        billing_interval: billing_interval,
        store_reference: ValueNormalization.redacted(store_reference),
        product_reference: ValueNormalization.redacted(product_reference),
        variant_reference: ValueNormalization::FILTERED
      }.compact.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end

    private

    def provider_reference(value, name)
      ValueNormalization.optional_string(
        value, name: name, maximum: 128, pattern: ValueNormalization::REFERENCE_PATTERN
      )
    end
  end
end
