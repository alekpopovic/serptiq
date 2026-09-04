# frozen_string_literal: true

module Billing
  ProviderEvent = Data.define(
    :provider, :reference, :name, :occurred_at, :customer_reference,
    :subscription_reference, :variant_reference, :metadata
  ) do
    NAMES = %w[
      subscription.created subscription.updated subscription.canceled subscription.resumed
      subscription.expired subscription.paused subscription.unpaused
      payment.succeeded payment.failed payment.recovered
    ].freeze

    def initialize(provider:, reference:, name:, occurred_at:, customer_reference: nil,
      subscription_reference: nil, variant_reference: nil, metadata: {})
      event_name = name.to_s
      raise ArgumentError, "provider event name is unsupported" unless NAMES.include?(event_name)

      super(
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        reference: ValueNormalization.string!(
          reference, name: "event reference", maximum: 191,
          pattern: ValueNormalization::REFERENCE_PATTERN
        ),
        name: event_name.freeze,
        occurred_at: ValueNormalization.time!(occurred_at, name: "event occurrence time"),
        customer_reference: optional_reference(customer_reference, "customer reference"),
        subscription_reference: optional_reference(subscription_reference, "subscription reference"),
        variant_reference: optional_reference(variant_reference, "variant reference"),
        metadata: ValueNormalization.metadata(metadata)
      )
      freeze
    end

    def as_json(*)
      {
        provider: provider,
        reference: ValueNormalization::FILTERED,
        name: name,
        occurred_at: occurred_at,
        customer_reference: ValueNormalization.redacted(customer_reference),
        subscription_reference: ValueNormalization.redacted(subscription_reference),
        variant_reference: ValueNormalization.redacted(variant_reference)
      }.compact.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end

    private

    def optional_reference(value, name)
      ValueNormalization.optional_string(
        value, name: name, maximum: 191, pattern: ValueNormalization::REFERENCE_PATTERN
      )
    end
  end
end
