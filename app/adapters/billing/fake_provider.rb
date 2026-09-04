# frozen_string_literal: true

require "json"
require "digest"
require "time"

module Billing
  class FakeProvider < Provider
    FAILURE_SCENARIOS = {
      authentication_failure: [ "authentication", false, nil ],
      authorization_failure: [ "authorization", false, nil ],
      rate_limited: [ "rate_limited", true, 30 ],
      timeout: [ "timeout", true, nil ],
      unavailable: [ "unavailable", true, nil ],
      malformed_response: [ "malformed_response", false, nil ]
    }.freeze

    attr_reader :calls

    def initialize(clock: -> { Time.current }, scenarios: {}, unsupported: [])
      @clock = clock
      @scenarios = scenarios.transform_keys(&:to_s)
      @unsupported = Array(unsupported).map(&:to_s).freeze
      @calls = []
    end

    def provider_key
      "fake"
    end

    def supports?(operation)
      super && !@unsupported.include?(operation.to_s)
    end

    def create_customer(request:)
      require_type!(request, CustomerRequest, "create_customer")
      perform("create_customer", request: request) do
        Customer.new(
          provider: provider_key,
          reference: "customer-#{Digest::SHA256.hexdigest(request.organization_id).first(24)}",
          organization_id: request.organization_id,
          email: request.email,
          created_at: @clock.call
        )
      end
    end

    def create_checkout(request:)
      require_type!(request, CheckoutRequest, "create_checkout")
      perform("create_checkout", request: request) do
        CheckoutResult.new(
          provider: provider_key,
          reference: "checkout-001",
          url: "https://billing.example.test/checkouts/checkout-001",
          created_at: @clock.call,
          expires_at: @clock.call + 30.minutes
        )
      end
    end

    def customer_portal(customer:, idempotency_key:)
      require_type!(customer, Customer, "customer_portal")
      validate_idempotency!(idempotency_key)
      perform("customer_portal", customer: customer) do
        PortalLink.new(
          provider: provider_key,
          url: "https://billing.example.test/portal/session-001",
          created_at: @clock.call,
          expires_at: @clock.call + 15.minutes
        )
      end
    end

    def fetch_subscription(reference:)
      reference = provider_reference!(reference)
      perform("fetch_subscription", reference: ValueNormalization::FILTERED) do
        subscription_snapshot(reference: reference)
      end
    end

    def change_subscription(subscription:, variant_reference:, idempotency_key:)
      require_type!(subscription, SubscriptionSnapshot, "change_subscription")
      variant = provider_reference!(variant_reference)
      validate_idempotency!(idempotency_key)
      perform("change_subscription", subscription: subscription) do
        subscription_snapshot(
          reference: subscription.subscription_reference,
          variant_reference: variant,
          status: "active",
          access_state: "full"
        )
      end
    end

    def cancel_subscription(subscription:, idempotency_key:, at_period_end: true)
      require_type!(subscription, SubscriptionSnapshot, "cancel_subscription")
      validate_idempotency!(idempotency_key)
      raise ArgumentError, "at_period_end must be boolean" unless [ true, false ].include?(at_period_end)

      perform("cancel_subscription", subscription: subscription) do
        subscription_snapshot(
          reference: subscription.subscription_reference,
          status: "canceled",
          access_state: at_period_end ? "full" : "read_only",
          cancel_at_period_end: at_period_end,
          canceled_at: @clock.call
        )
      end
    end

    def resume_subscription(subscription:, idempotency_key:)
      require_type!(subscription, SubscriptionSnapshot, "resume_subscription")
      validate_idempotency!(idempotency_key)
      perform("resume_subscription", subscription: subscription) do
        subscription_snapshot(reference: subscription.subscription_reference)
      end
    end

    def reconciliation_page(page_number: 1, page_size: 100)
      unless page_number.is_a?(Integer) && page_number.positive? && page_size.is_a?(Integer) && page_size.between?(1, 100)
        raise ArgumentError, "reconciliation page is invalid"
      end

      perform("reconciliation_page", page_number: page_number, page_size: page_size) do
        SubscriptionPage.new(
          subscriptions: [ subscription_snapshot(reference: "subscription-001") ],
          next_page: nil,
          total: 1
        )
      end
    end

    def verify_webhook(raw_body:, headers:)
      perform("verify_webhook", body_bytes: raw_body.to_s.bytesize) do
        signature = headers.to_h["X-Fake-Signature"] || headers.to_h["x-fake-signature"]
        unless signature == "valid"
          raise ProviderFailure.new(
            provider: provider_key,
            operation: "verify_webhook",
            category: "signature_invalid",
            retryable: false
          )
        end

        VerifiedWebhook.new(provider: provider_key, raw_body: raw_body, received_at: @clock.call)
      end
    end

    def parse_event(webhook:)
      require_type!(webhook, VerifiedWebhook, "parse_event")
      perform("parse_event", body_bytes: webhook.raw_body.bytesize) do
        payload = JSON.parse(webhook.raw_body)
        ProviderEvent.new(
          provider: provider_key,
          reference: payload.fetch("id"),
          name: payload.fetch("name"),
          occurred_at: Time.iso8601(payload.fetch("occurred_at")),
          customer_reference: payload["customer_id"],
          subscription_reference: payload["subscription_id"],
          variant_reference: payload["variant_id"],
          metadata: payload.fetch("metadata", {})
        )
      rescue JSON::ParserError, KeyError, ArgumentError => error
        raise ProviderFailure.new(
          provider: provider_key,
          operation: "parse_event",
          category: "malformed_response",
          retryable: false
        ), cause: error
      end
    end

    private

    def perform(operation, **safe_request)
      unsupported!(operation) unless supports?(operation)
      fail_for_scenario!(operation)
      calls << { operation: operation.freeze, request: safe_request.freeze }.freeze
      yield
    end

    def unsupported!(operation)
      raise ProviderFailure.new(
        provider: provider_key,
        operation: operation,
        category: "unsupported_operation",
        retryable: false
      )
    end

    def fail_for_scenario!(operation)
      scenario = @scenarios.fetch(operation, :success).to_sym
      return if scenario == :success

      category, retryable, retry_after = FAILURE_SCENARIOS.fetch(scenario) do
        raise ArgumentError, "unknown fake billing scenario"
      end
      raise ProviderFailure.new(
        provider: provider_key,
        operation: operation,
        category: category,
        retryable: retryable,
        retry_after: retry_after
      )
    end

    def require_type!(value, expected, operation)
      return if value.is_a?(expected)

      raise ArgumentError, "#{operation} requires #{expected.name}"
    end

    def validate_idempotency!(value)
      ValueNormalization.string!(value, name: "idempotency key", maximum: 200)
    end

    def provider_reference!(value)
      ValueNormalization.string!(
        value, name: "provider reference", maximum: 191,
        pattern: ValueNormalization::REFERENCE_PATTERN
      )
    end

    def subscription_snapshot(reference:, variant_reference: "variant-001", status: "active",
      access_state: "full", cancel_at_period_end: false, canceled_at: nil)
      SubscriptionSnapshot.new(
        provider: provider_key,
        customer_reference: "customer-001",
        subscription_reference: reference,
        variant_reference: variant_reference,
        status: status,
        access_state: access_state,
        billing_interval: "monthly",
        currency: "EUR",
        current_period_starts_at: @clock.call.beginning_of_month,
        current_period_ends_at: @clock.call.next_month.beginning_of_month,
        cancel_at_period_end: cancel_at_period_end,
        canceled_at: canceled_at,
        provider_updated_at: @clock.call,
        metadata: { "raw_status" => status }
      )
    end
  end
end
