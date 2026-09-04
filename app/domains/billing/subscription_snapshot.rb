# frozen_string_literal: true

module Billing
  SubscriptionSnapshot = Data.define(
    :provider, :customer_reference, :subscription_reference, :variant_reference,
    :status, :access_state, :billing_interval, :currency, :current_period_starts_at,
    :current_period_ends_at, :trial_ends_at, :cancel_at_period_end, :canceled_at,
    :ended_at, :provider_updated_at, :invoice_link, :metadata
  ) do
    BILLING_INTERVALS = %w[monthly annual custom].freeze

    def initialize(provider:, customer_reference:, subscription_reference:, variant_reference:,
      status:, access_state:, billing_interval:, currency:, provider_updated_at:,
      current_period_starts_at: nil, current_period_ends_at: nil, trial_ends_at: nil,
      cancel_at_period_end: false, canceled_at: nil, ended_at: nil, invoice_link: nil,
      metadata:)
      normalized_status = status.to_s
      normalized_access = access_state.to_s
      raise ArgumentError, "subscription lifecycle is invalid" unless
        SubscriptionLifecycle.valid?(status: normalized_status, access_state: normalized_access)
      interval = billing_interval.to_s
      raise ArgumentError, "billing interval is invalid" unless BILLING_INTERVALS.include?(interval)
      currency = ValueNormalization.string!(currency, name: "currency", maximum: 3, pattern: /\A[A-Z]{3}\z/)
      period_start = ValueNormalization.time!(
        current_period_starts_at, name: "period start", optional: true
      )
      period_end = ValueNormalization.time!(current_period_ends_at, name: "period end", optional: true)
      unless (period_start.nil? && period_end.nil?) || (period_start && period_end && period_end > period_start)
        raise ArgumentError, "subscription period is invalid"
      end
      ending = ValueNormalization.time!(ended_at, name: "subscription end", optional: true)
      unless (normalized_status == "expired") == ending.present?
        raise ArgumentError, "subscription end does not match status"
      end
      raise ArgumentError, "cancel_at_period_end must be boolean" unless [ true, false ].include?(cancel_at_period_end)
      cancellation = ValueNormalization.time!(canceled_at, name: "cancellation time", optional: true)
      cancellation_required = cancel_at_period_end || normalized_status == "canceled"
      if cancellation_required != cancellation.present? && normalized_status != "expired"
        raise ArgumentError, "cancellation time does not match subscription state"
      end
      metadata = ValueNormalization.metadata(metadata)
      raise ArgumentError, "raw provider status metadata is required" unless metadata.key?("raw_status")
      if invoice_link && !invoice_link.is_a?(InvoiceTransactionLink)
        raise ArgumentError, "invoice link is invalid"
      end

      super(
        provider: provider_reference(provider, "provider", ValueNormalization::PROVIDER_PATTERN, 32),
        customer_reference: provider_reference(customer_reference, "customer reference"),
        subscription_reference: provider_reference(subscription_reference, "subscription reference"),
        variant_reference: provider_reference(variant_reference, "variant reference"),
        status: normalized_status.freeze,
        access_state: normalized_access.freeze,
        billing_interval: interval.freeze,
        currency: currency,
        current_period_starts_at: period_start,
        current_period_ends_at: period_end,
        trial_ends_at: ValueNormalization.time!(trial_ends_at, name: "trial end", optional: true),
        cancel_at_period_end: cancel_at_period_end,
        canceled_at: cancellation,
        ended_at: ending,
        provider_updated_at: ValueNormalization.time!(provider_updated_at, name: "provider update time"),
        invoice_link: invoice_link,
        metadata: metadata
      )
      freeze
    end

    def current?
      SubscriptionLifecycle::CURRENT_STATUSES.include?(status)
    end

    def as_json(*)
      {
        provider: provider,
        customer_reference: ValueNormalization::FILTERED,
        subscription_reference: ValueNormalization::FILTERED,
        variant_reference: ValueNormalization::FILTERED,
        status: status,
        access_state: access_state,
        billing_interval: billing_interval,
        currency: currency,
        current_period_starts_at: current_period_starts_at,
        current_period_ends_at: current_period_ends_at,
        trial_ends_at: trial_ends_at,
        cancel_at_period_end: cancel_at_period_end,
        canceled_at: canceled_at,
        ended_at: ended_at,
        provider_updated_at: provider_updated_at,
        invoice_link: invoice_link&.as_json
      }.compact.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end

    private

    def provider_reference(value, name, pattern = ValueNormalization::REFERENCE_PATTERN, maximum = 191)
      ValueNormalization.string!(value, name: name, maximum: maximum, pattern: pattern)
    end
  end
end
