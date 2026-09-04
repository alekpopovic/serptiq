# frozen_string_literal: true

require "digest"
require "json"
require "openssl"
require "time"

module Billing
  class LemonSqueezyProvider < Provider
    PROVIDER_KEY = "lemon_squeezy"
    ENVIRONMENTS = %w[development test staging production].freeze
    WEBHOOK_EVENTS = {
      "subscription_created" => "subscription.created",
      "subscription_updated" => "subscription.updated",
      "subscription_cancelled" => "subscription.canceled",
      "subscription_resumed" => "subscription.resumed",
      "subscription_expired" => "subscription.expired",
      "subscription_paused" => "subscription.paused",
      "subscription_unpaused" => "subscription.unpaused",
      "subscription_payment_success" => "payment.succeeded",
      "subscription_payment_failed" => "payment.failed",
      "subscription_payment_recovered" => "payment.recovered"
    }.freeze

    def self.from_settings(settings: Rails.application.config.x.searchops, environment: Rails.env.to_s,
      transport: LemonSqueezy::NetHttpTransport.new, sleeper: ->(delay) { sleep(delay) },
      clock: -> { Time.current }, instrumentation: LemonSqueezy::Instrumentation.new)
      new(
        api_key: settings.secret(:billing_api_key),
        webhook_secret: settings.secret(:billing_webhook_secret),
        store_reference: settings.fetch(:billing_store_id),
        environment: environment,
        open_timeout: settings.fetch(:billing_http_open_timeout),
        read_timeout: settings.fetch(:billing_http_read_timeout),
        write_timeout: settings.fetch(:billing_http_write_timeout),
        max_response_bytes: settings.fetch(:billing_http_max_response_bytes),
        transport: transport,
        sleeper: sleeper,
        clock: clock,
        instrumentation: instrumentation
      )
    end

    def initialize(api_key:, webhook_secret:, store_reference:, environment:, open_timeout: 2.0,
      read_timeout: 5.0, write_timeout: 5.0, max_response_bytes: 524_288,
      transport: LemonSqueezy::NetHttpTransport.new, sleeper: ->(delay) { sleep(delay) },
      clock: -> { Time.current }, instrumentation: LemonSqueezy::Instrumentation.new, mapping_lookup: nil)
      @store_reference = numeric_reference(store_reference, "store reference")
      @environment = ValueNormalization.string!(environment, name: "environment", maximum: 16)
      raise ArgumentError, "billing environment is invalid" unless ENVIRONMENTS.include?(@environment)

      @webhook_secret = ValueNormalization.string!(
        webhook_secret, name: "billing webhook secret", maximum: 512
      )
      @clock = clock
      expected_test_mode = %w[development test].include?(@environment)
      mapping_lookup ||= LemonSqueezyPlanMappingLookup.new(
        environment: @environment,
        store_reference: @store_reference
      )
      @normalizer = LemonSqueezy::Normalizer.new(
        store_reference: @store_reference,
        expected_test_mode: expected_test_mode,
        mapping_lookup: mapping_lookup,
        clock: clock
      )
      @client = LemonSqueezy::Client.new(
        api_key: api_key,
        open_timeout: open_timeout,
        read_timeout: read_timeout,
        write_timeout: write_timeout,
        max_response_bytes: max_response_bytes,
        transport: transport,
        sleeper: sleeper,
        clock: clock,
        instrumentation: instrumentation
      )
    end

    def provider_key
      PROVIDER_KEY
    end

    def create_checkout(request:)
      require_type!(request, CheckoutRequest, "create_checkout")
      variant = numeric_reference(request.variant_reference, "variant reference")
      expires_at = @clock.call + 30.minutes
      payload = {
        "data" => {
          "type" => "checkouts",
          "attributes" => {
            "product_options" => {
              "redirect_url" => request.success_url,
              "enabled_variants" => [ Integer(variant, 10) ]
            },
            "checkout_data" => {
              "email" => request.email,
              "custom" => checkout_custom_data(request)
            }.compact,
            "expires_at" => expires_at.iso8601,
            "test_mode" => %w[development test].include?(@environment)
          },
          "relationships" => {
            "store" => { "data" => { "type" => "stores", "id" => @store_reference } },
            "variant" => { "data" => { "type" => "variants", "id" => variant } }
          }
        }
      }
      normalize("create_checkout") do
        @normalizer.checkout(
          @client.create_checkout(payload: payload, correlation_key: request.idempotency_key),
          expected_variant: variant
        )
      end
    end

    def customer_portal(customer:, idempotency_key:)
      require_type!(customer, Customer, "customer_portal")
      require_provider!(customer.provider, "customer_portal")
      validate_idempotency!(idempotency_key)
      reference = numeric_reference(customer.reference, "customer reference")
      normalize("customer_portal") do
        @normalizer.portal(
          @client.retrieve_customer(reference: reference, correlation_key: idempotency_key),
          expected_reference: reference
        )
      end
    end

    def fetch_subscription(reference:)
      reference = numeric_reference(reference, "subscription reference")
      normalize("fetch_subscription") do
        @normalizer.subscription(
          @client.retrieve_subscription(reference: reference),
          expected_reference: reference
        )
      end
    end

    def change_subscription(subscription:, variant_reference:, idempotency_key:)
      require_subscription!(subscription, "change_subscription")
      validate_idempotency!(idempotency_key)
      variant = numeric_reference(variant_reference, "variant reference")
      mutate_subscription(
        subscription,
        operation: "change_subscription",
        attributes: { "variant_id" => Integer(variant, 10) },
        idempotency_key: idempotency_key
      )
    end

    def cancel_subscription(subscription:, idempotency_key:, at_period_end: true)
      require_subscription!(subscription, "cancel_subscription")
      validate_idempotency!(idempotency_key)
      unless at_period_end == true
        raise ProviderFailure.new(
          provider: provider_key,
          operation: "cancel_subscription",
          category: "unsupported_operation",
          retryable: false
        )
      end

      normalize("cancel_subscription") do
        @normalizer.subscription(
          @client.cancel_subscription(
            reference: subscription.subscription_reference,
            correlation_key: idempotency_key
          ),
          expected_reference: subscription.subscription_reference
        )
      end
    end

    def resume_subscription(subscription:, idempotency_key:)
      require_subscription!(subscription, "resume_subscription")
      validate_idempotency!(idempotency_key)
      mutate_subscription(
        subscription,
        operation: "resume_subscription",
        attributes: { "cancelled" => false },
        idempotency_key: idempotency_key
      )
    end

    def reconciliation_page(page_number: 1, page_size: 100)
      normalize("reconciliation_page") do
        @normalizer.subscription_page(
          @client.list_subscriptions(
            store_reference: @store_reference,
            page_number: page_number,
            page_size: page_size
          )
        )
      end
    end

    def verify_webhook(raw_body:, headers:)
      webhook = VerifiedWebhook.new(provider: provider_key, raw_body: raw_body, received_at: @clock.call)
      signature = header(headers, "x-signature")
      expected = OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, webhook.raw_body)
      valid = signature&.match?(/\A[0-9a-f]{64}\z/i) &&
        ActiveSupport::SecurityUtils.secure_compare(signature.downcase, expected)
      unless valid
        raise ProviderFailure.new(
          provider: provider_key,
          operation: "verify_webhook",
          category: "signature_invalid",
          retryable: false
        )
      end

      webhook
    end

    def parse_event(webhook:)
      require_type!(webhook, VerifiedWebhook, "parse_event")
      require_provider!(webhook.provider, "parse_event")
      payload = JSON.parse(webhook.raw_body, max_nesting: 32)
      meta = required_hash(payload, "meta")
      data = required_hash(payload, "data")
      attributes = required_hash(data, "attributes")
      event_name = ValueNormalization.string!(
        meta.fetch("event_name"), name: "webhook event name", maximum: 64,
        pattern: ValueNormalization::KEY_PATTERN
      )
      canonical_name = WEBHOOK_EVENTS.fetch(event_name) do
        raise ArgumentError, "webhook event is unsupported"
      end
      validate_event_environment!(meta, attributes)
      ProviderEvent.new(
        provider: provider_key,
        reference: "event-#{Digest::SHA256.hexdigest(webhook.raw_body)}",
        name: canonical_name,
        occurred_at: event_time(attributes),
        customer_reference: optional_numeric(attributes["customer_id"], "customer reference"),
        subscription_reference: event_subscription_reference(data, attributes),
        variant_reference: optional_numeric(attributes["variant_id"], "variant reference"),
        metadata: event_metadata(meta, event_name)
      )
    rescue JSON::ParserError, JSON::NestingError, KeyError, ArgumentError
      raise ProviderFailure.new(
        provider: provider_key,
        operation: "parse_event",
        category: "malformed_response",
        retryable: false
      ), cause: nil
    end

    def inspect
      "#<#{self.class.name} provider=#{provider_key.inspect} environment=#{@environment.inspect} " \
        "store_reference=[FILTERED] credentials=[FILTERED]>"
    end

    private

    def mutate_subscription(subscription, operation:, attributes:, idempotency_key:)
      normalize(operation) do
        @normalizer.subscription(
          @client.update_subscription(
            reference: subscription.subscription_reference,
            attributes: attributes,
            operation: operation,
            correlation_key: idempotency_key
          ),
          expected_reference: subscription.subscription_reference
        )
      end
    end

    def checkout_custom_data(request)
      {
        "organization_id" => request.organization_id,
        "plan_version_id" => request.plan_version_id,
        "operation_id" => Digest::SHA256.hexdigest(request.idempotency_key).first(32)
      }
    end

    def normalize(operation)
      yield
    rescue ProviderFailure, ProviderMappingMissing
      raise
    rescue KeyError, ArgumentError, TypeError
      raise ProviderFailure.new(
        provider: provider_key,
        operation: operation,
        category: "malformed_response",
        retryable: false
      ), cause: nil
    end

    def require_type!(value, expected, operation)
      return if value.is_a?(expected)

      raise ArgumentError, "#{operation} requires #{expected.name}"
    end

    def require_subscription!(value, operation)
      require_type!(value, SubscriptionSnapshot, operation)
      require_provider!(value.provider, operation)
    end

    def require_provider!(value, operation)
      raise ArgumentError, "#{operation} provider mismatch" unless value == provider_key
    end

    def validate_idempotency!(value)
      ValueNormalization.string!(value, name: "idempotency key", maximum: 200)
    end

    def numeric_reference(value, name)
      ValueNormalization.string!(
        value, name: name, maximum: 19,
        pattern: PlanProviderMapping::LEMON_SQUEEZY_REFERENCE_PATTERN
      )
    end

    def optional_numeric(value, name)
      value.nil? ? nil : numeric_reference(value, name)
    end

    def header(headers, expected)
      headers.to_h.each do |key, value|
        return value.to_s if key.to_s.downcase == expected
      end
      nil
    end

    def required_hash(value, key)
      result = value.fetch(key)
      raise ArgumentError, "#{key} is invalid" unless result.is_a?(Hash)

      result
    end

    def validate_event_environment!(meta, attributes)
      store = numeric_reference(attributes.fetch("store_id"), "store reference")
      raise ArgumentError, "webhook store is invalid" unless store == @store_reference
      expected_test_mode = %w[development test].include?(@environment)
      test_mode = meta.key?("test_mode") ? meta["test_mode"] : attributes["test_mode"]
      raise ArgumentError, "webhook environment is invalid" unless test_mode == expected_test_mode
    end

    def event_time(attributes)
      raw = attributes["updated_at"] || attributes["created_at"]
      Time.iso8601(ValueNormalization.string!(raw, name: "webhook event time", maximum: 64))
    end

    def event_subscription_reference(data, attributes)
      value = if data["type"] == "subscriptions"
        data["id"]
      else
        attributes["subscription_id"]
      end
      optional_numeric(value, "subscription reference")
    end

    def event_metadata(meta, event_name)
      metadata = {
        "raw_event_name" => event_name,
        "test_mode" => %w[development test].include?(@environment)
      }
      custom = meta["custom_data"]
      if custom.is_a?(Hash)
        %w[organization_id plan_version_id operation_id].each do |key|
          value = custom[key]
          metadata[key] = value if safe_custom_value?(key, value)
        end
      end
      metadata
    end

    def safe_custom_value?(key, value)
      return Shared::Public.application_uuid?(value) if %w[organization_id plan_version_id].include?(key)

      value.to_s.match?(/\A[0-9a-f]{32}\z/)
    end
  end
end
