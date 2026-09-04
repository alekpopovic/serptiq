# frozen_string_literal: true

module Billing
  CheckoutRequest = Data.define(
    :organization_id, :plan_version_id, :variant_reference, :customer_reference,
    :email, :success_url, :cancel_url, :idempotency_key, :metadata
  ) do
    def initialize(organization_id:, plan_version_id:, variant_reference:, success_url:, cancel_url:,
      idempotency_key:, customer_reference: nil, email: nil, metadata: {})
      super(
        organization_id: ValueNormalization.uuid!(organization_id, name: "organization"),
        plan_version_id: ValueNormalization.uuid!(plan_version_id, name: "plan version"),
        variant_reference: ValueNormalization.string!(
          variant_reference, name: "variant reference", maximum: 191,
          pattern: ValueNormalization::REFERENCE_PATTERN
        ),
        customer_reference: ValueNormalization.optional_string(
          customer_reference, name: "customer reference", maximum: 191,
          pattern: ValueNormalization::REFERENCE_PATTERN
        ),
        email: ValueNormalization.optional_string(
          email, name: "email", maximum: 320, pattern: ValueNormalization::EMAIL_PATTERN
        ),
        success_url: ValueNormalization.url!(success_url, name: "success URL"),
        cancel_url: ValueNormalization.url!(cancel_url, name: "cancel URL"),
        idempotency_key: ValueNormalization.string!(idempotency_key, name: "idempotency key", maximum: 200),
        metadata: ValueNormalization.metadata(metadata)
      )
      freeze
    end

    def as_json(*)
      {
        organization_id: organization_id,
        plan_version_id: plan_version_id,
        variant_reference: ValueNormalization::FILTERED,
        customer_reference: ValueNormalization.redacted(customer_reference),
        email: ValueNormalization.redacted(email),
        success_url: ValueNormalization::FILTERED,
        cancel_url: ValueNormalization::FILTERED,
        idempotency_key: ValueNormalization::FILTERED
      }.compact.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end
  end
end
