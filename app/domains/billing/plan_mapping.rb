# frozen_string_literal: true

module Billing
  PlanMapping = Data.define(
    :plan_version_id, :provider, :environment, :currency, :billing_interval, :variant_reference
  ) do
    def initialize(plan_version_id:, provider:, environment:, currency:, billing_interval:, variant_reference:)
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
        variant_reference: ValueNormalization::FILTERED
      }.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end
  end
end
