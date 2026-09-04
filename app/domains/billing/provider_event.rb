# frozen_string_literal: true

module Billing
  ProviderEvent = Data.define(
    :provider, :reference, :name, :occurred_at, :customer_reference,
    :subscription_reference, :variant_reference, :metadata, :subscription_snapshot
  ) do
    def initialize(provider:, reference:, name:, occurred_at:, customer_reference: nil,
      subscription_reference: nil, variant_reference: nil, metadata: {}, subscription_snapshot: nil)
      event_name = name.to_s
      raise ArgumentError, "provider event name is unsupported" unless self.class::NAMES.include?(event_name)
      normalized_provider = ValueNormalization.string!(
        provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
      )

      super(
        provider: normalized_provider,
        reference: ValueNormalization.string!(
          reference, name: "event reference", maximum: 191,
          pattern: ValueNormalization::REFERENCE_PATTERN
        ),
        name: event_name.freeze,
        occurred_at: ValueNormalization.time!(occurred_at, name: "event occurrence time"),
        customer_reference: optional_reference(customer_reference, "customer reference"),
        subscription_reference: optional_reference(subscription_reference, "subscription reference"),
        variant_reference: optional_reference(variant_reference, "variant reference"),
        metadata: ValueNormalization.metadata(metadata),
        subscription_snapshot: normalize_snapshot(subscription_snapshot, normalized_provider)
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

    def normalize_snapshot(value, expected_provider)
      return if value.nil?
      return value if value.is_a?(SubscriptionSnapshot) && value.provider == expected_provider

      raise ArgumentError, "subscription snapshot is invalid"
    end
  end

  ProviderEvent::NAMES = %w[
    subscription.created subscription.updated subscription.canceled subscription.resumed
    subscription.expired subscription.paused subscription.unpaused
    payment.succeeded payment.failed payment.recovered payment.refunded
    order.created order.refunded
  ].freeze
end
