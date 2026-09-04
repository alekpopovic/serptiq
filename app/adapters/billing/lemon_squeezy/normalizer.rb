# frozen_string_literal: true

require "time"
require "uri"

module Billing
  module LemonSqueezy
    class Normalizer
      STATUS_MAP = {
        "on_trial" => [ "trialing", "full" ],
        "active" => [ "active", "full" ],
        "paused" => [ "paused", "read_only" ],
        "past_due" => [ "past_due", "grace" ],
        "unpaid" => [ "past_due", "read_only" ],
        "cancelled" => [ "canceled", "full" ],
        "expired" => [ "expired", "read_only" ]
      }.freeze

      def initialize(store_reference:, expected_test_mode:, mapping_lookup:, clock: -> { Time.current })
        @store_reference = numeric_reference(store_reference, "store reference")
        unless [ true, false ].include?(expected_test_mode)
          raise ArgumentError, "expected test mode must be boolean"
        end

        @expected_test_mode = expected_test_mode
        @mapping_lookup = mapping_lookup
        @clock = clock
      end

      def checkout(payload, expected_variant:)
        data = resource(payload, type: "checkouts")
        attributes = attributes(data)
        validate_catalog!(
          attributes,
          expected_variant: numeric_reference(expected_variant, "variant reference")
        )
        CheckoutResult.new(
          provider: "lemon_squeezy",
          reference: provider_reference(data.fetch("id"), "checkout reference"),
          url: required_string(attributes, "url"),
          created_at: timestamp(attributes, "created_at"),
          expires_at: timestamp(attributes, "expires_at")
        )
      end

      def customer(payload, organization_id:, expected_reference: nil)
        data = resource(payload, type: "customers", expected_reference: expected_reference)
        attributes = attributes(data)
        validate_store_and_mode!(attributes)
        Customer.new(
          provider: "lemon_squeezy",
          reference: provider_reference(data.fetch("id"), "customer reference"),
          organization_id: ValueNormalization.uuid!(organization_id, name: "organization"),
          email: required_string(attributes, "email"),
          created_at: timestamp(attributes, "created_at"),
          metadata: { "test_mode" => @expected_test_mode }
        )
      end

      def portal(payload, expected_reference:)
        data = resource(payload, type: "customers", expected_reference: expected_reference)
        attributes = attributes(data)
        validate_store_and_mode!(attributes)
        urls = required_hash(attributes, "urls")
        PortalLink.new(
          provider: "lemon_squeezy",
          url: required_string(urls, "customer_portal"),
          created_at: @clock.call,
          expires_at: @clock.call + 24.hours
        )
      end

      def subscription(payload, expected_reference: nil)
        data = resource(payload, type: "subscriptions", expected_reference: expected_reference)
        normalize_subscription_resource(data)
      end

      def subscription_page(payload)
        data = payload.fetch("data")
        raise ArgumentError, "subscription collection is invalid" unless data.is_a?(Array) && data.length <= 100

        subscriptions = data.map do |resource_data|
          unless resource_data.is_a?(Hash) && resource_data["type"] == "subscriptions"
            raise ArgumentError, "subscription collection resource is invalid"
          end

          normalize_subscription_resource(resource_data)
        end
        page = required_hash(required_hash(payload, "meta"), "page")
        total = integer(page.fetch("total"), name: "subscription total", range: 0..1_000_000_000)
        next_page = next_page_number(payload["links"])
        SubscriptionPage.new(subscriptions: subscriptions, next_page: next_page, total: total)
      end

      private

      def normalize_subscription_resource(data)
        attributes = attributes(data)
        validate_store_and_mode!(attributes)
        raw_status = required_string(attributes, "status")
        status, access_state = STATUS_MAP.fetch(raw_status) do
          raise ArgumentError, "subscription status is unsupported"
        end
        pause = attributes["pause"]
        if raw_status == "paused"
          unless pause.is_a?(Hash) && %w[free void].include?(pause["mode"])
            raise ArgumentError, "subscription pause is invalid"
          end
          access_state = "suspended" if pause["mode"] == "void"
        elsif pause.present?
          raise ArgumentError, "subscription pause is inconsistent"
        end
        customer_reference = numeric_reference(attributes.fetch("customer_id"), "customer reference")
        product_reference = numeric_reference(attributes.fetch("product_id"), "product reference")
        variant_reference = numeric_reference(attributes.fetch("variant_id"), "variant reference")
        mapping = @mapping_lookup.call(
          variant_reference: variant_reference,
          product_reference: product_reference,
          store_reference: attributes.fetch("store_id")
        )
        updated_at = timestamp(attributes, "updated_at")
        provider_ends_at = optional_timestamp(attributes, "ends_at")
        renewal_at = optional_timestamp(attributes, "renews_at")
        canceled = raw_status == "cancelled"
        raw_cancelled = attributes.fetch("cancelled")
        raise ArgumentError, "subscription cancellation flag is invalid" unless [ true, false ].include?(raw_cancelled)
        expected_cancelled = %w[cancelled expired].include?(raw_status)
        unless raw_cancelled == expected_cancelled && (!canceled || provider_ends_at)
          raise ArgumentError, "subscription cancellation state is inconsistent"
        end
        ended_at = raw_status == "expired" ? (provider_ends_at || updated_at) : nil
        metadata = {
          "raw_status" => raw_status,
          "test_mode" => @expected_test_mode,
          "raw_cancelled" => raw_cancelled
        }
        metadata["raw_pause_mode"] = pause["mode"] if pause.is_a?(Hash) && pause["mode"].is_a?(String)
        metadata["cancellation_time_source"] = "provider_updated_at" if canceled

        SubscriptionSnapshot.new(
          provider: "lemon_squeezy",
          customer_reference: customer_reference,
          subscription_reference: numeric_reference(data.fetch("id"), "subscription reference"),
          variant_reference: variant_reference,
          status: status,
          access_state: access_state,
          billing_interval: mapping.billing_interval,
          currency: mapping.currency,
          started_at: timestamp(attributes, "created_at"),
          trial_ends_at: optional_timestamp(attributes, "trial_ends_at"),
          current_period_ends_at: canceled ? provider_ends_at : renewal_at,
          cancel_at_period_end: canceled,
          canceled_at: canceled ? updated_at : nil,
          access_expires_at: canceled ? provider_ends_at : nil,
          ended_at: ended_at,
          provider_updated_at: updated_at,
          metadata: metadata
        )
      end

      def resource(payload, type:, expected_reference: nil)
        data = payload.fetch("data")
        raise ArgumentError, "provider resource is invalid" unless data.is_a?(Hash) && data["type"] == type
        if expected_reference && data["id"].to_s != expected_reference.to_s
          raise ArgumentError, "provider resource identity is invalid"
        end

        data
      end

      def attributes(data)
        required_hash(data, "attributes")
      end

      def validate_catalog!(attributes, expected_variant:)
        validate_store_and_mode!(attributes)
        actual = numeric_reference(attributes.fetch("variant_id"), "variant reference")
        raise ArgumentError, "provider variant is invalid" unless actual == expected_variant
      end

      def validate_store_and_mode!(attributes)
        store = numeric_reference(attributes.fetch("store_id"), "store reference")
        raise ArgumentError, "provider store is invalid" unless store == @store_reference
        unless attributes["test_mode"] == @expected_test_mode
          raise ArgumentError, "provider environment is invalid"
        end
      end

      def required_hash(value, key)
        result = value.fetch(key)
        raise ArgumentError, "#{key} is invalid" unless result.is_a?(Hash)

        result
      end

      def required_string(value, key)
        ValueNormalization.string!(value.fetch(key), name: key.tr("_", " "), maximum: 2048)
      end

      def timestamp(value, key)
        parse_time(value.fetch(key), name: key)
      end

      def optional_timestamp(value, key)
        raw = value[key]
        raw.nil? ? nil : parse_time(raw, name: key)
      end

      def parse_time(value, name:)
        Time.iso8601(ValueNormalization.string!(value, name: name, maximum: 64))
      rescue ArgumentError
        raise ArgumentError, "#{name} is invalid", cause: nil
      end

      def numeric_reference(value, name)
        ValueNormalization.string!(
          value, name: name, maximum: 19,
          pattern: PlanProviderMapping::LEMON_SQUEEZY_REFERENCE_PATTERN
        )
      end

      def provider_reference(value, name)
        ValueNormalization.string!(
          value, name: name, maximum: 191, pattern: ValueNormalization::REFERENCE_PATTERN
        )
      end

      def integer(value, name:, range:)
        result = Integer(value)
        raise ArgumentError, "#{name} is invalid" unless range.cover?(result)

        result
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} is invalid", cause: nil
      end

      def next_page_number(links)
        return unless links.is_a?(Hash) && links["next"].present?

        uri = URI.parse(links.fetch("next"))
        unless uri.scheme == "https" && uri.host == "api.lemonsqueezy.com" && uri.port == 443 &&
            uri.userinfo.nil? && uri.fragment.nil? && uri.path == "/v1/subscriptions"
          raise ArgumentError, "subscription pagination link is invalid"
        end
        parameters = URI.decode_www_form(uri.query.to_s).to_h
        integer(parameters.fetch("page[number]"), name: "next page", range: 1..1_000_000)
      rescue URI::InvalidURIError, KeyError
        raise ArgumentError, "subscription pagination link is invalid", cause: nil
      end
    end
  end
end
