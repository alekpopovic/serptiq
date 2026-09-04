# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "time"
require "uri"

module Billing
  module LemonSqueezy
    class Client
      API_ORIGIN = "https://api.lemonsqueezy.com"
      JSON_API_CONTENT_TYPE = "application/vnd.api+json"
      JSON_API_RESPONSE = %r{\Aapplication/vnd\.api\+json(?:\s*;|\z)}i
      MAX_REQUEST_BYTES = 65_536
      MAX_RETRY_DELAY = 2
      MAX_PAGE_SIZE = 100

      def initialize(api_key:, open_timeout:, read_timeout:, write_timeout:, max_response_bytes:,
        transport: NetHttpTransport.new, sleeper: ->(delay) { sleep(delay) }, clock: -> { Time.now },
        monotonic_clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, instrumentation: Instrumentation.new)
        @api_key = ValueNormalization.string!(api_key, name: "billing API key", maximum: 512)
        @open_timeout = open_timeout
        @read_timeout = read_timeout
        @write_timeout = write_timeout
        @max_response_bytes = max_response_bytes
        @transport = transport
        @sleeper = sleeper
        @clock = clock
        @monotonic_clock = monotonic_clock
        @instrumentation = instrumentation
        validate_limits!
      end

      def create_checkout(payload:, correlation_key:)
        request_json(
          method: :post,
          path: "/v1/checkouts",
          operation: "create_checkout",
          payload: payload,
          correlation_key: correlation_key,
          safe_retries: 0
        )
      end

      def create_customer(payload:, correlation_key:)
        request_json(
          method: :post,
          path: "/v1/customers",
          operation: "create_customer",
          payload: payload,
          correlation_key: correlation_key,
          safe_retries: 0
        )
      end

      def retrieve_customer(reference:, correlation_key: nil)
        request_json(
          method: :get,
          path: "/v1/customers/#{numeric_reference(reference)}",
          operation: "customer_portal",
          correlation_key: correlation_key,
          safe_retries: 0
        )
      end

      def retrieve_subscription(reference:)
        request_json(
          method: :get,
          path: "/v1/subscriptions/#{numeric_reference(reference)}",
          operation: "fetch_subscription",
          safe_retries: Provider::OPERATION_POLICIES.fetch("fetch_subscription").safe_retries
        )
      end

      def update_subscription(reference:, attributes:, operation:, correlation_key:)
        request_json(
          method: :patch,
          path: "/v1/subscriptions/#{numeric_reference(reference)}",
          operation: operation,
          payload: json_api_subscription(reference, attributes),
          correlation_key: correlation_key,
          safe_retries: 0
        )
      end

      def cancel_subscription(reference:, correlation_key:)
        request_json(
          method: :delete,
          path: "/v1/subscriptions/#{numeric_reference(reference)}",
          operation: "cancel_subscription",
          correlation_key: correlation_key,
          safe_retries: 0
        )
      end

      def list_subscriptions(store_reference:, page_number:, page_size: MAX_PAGE_SIZE)
        page = bounded_integer(page_number, name: "page number", range: 1..1_000_000)
        size = bounded_integer(page_size, name: "page size", range: 1..MAX_PAGE_SIZE)
        query = URI.encode_www_form(
          "filter[store_id]" => numeric_reference(store_reference),
          "page[number]" => page,
          "page[size]" => size
        )
        request_json(
          method: :get,
          path: "/v1/subscriptions?#{query}",
          operation: "reconciliation_page",
          safe_retries: Provider::OPERATION_POLICIES.fetch("reconciliation_page").safe_retries
        )
      end

      def inspect
        "#<#{self.class.name} api_origin=#{API_ORIGIN.inspect} api_key=[FILTERED]>"
      end

      private

      def request_json(method:, path:, operation:, safe_retries:, payload: nil, correlation_key: nil)
        uri = endpoint(path)
        body = encode_payload(payload)
        attempts = 0

        loop do
          response = nil
          started = @monotonic_clock.call
          begin
            response = perform_request(
              method: method,
              uri: uri,
              body: body,
              correlation_key: correlation_key,
              operation: operation
            )
            parsed = parse_response(response, operation: operation)
            emit(
              outcome: "succeeded",
              operation: operation,
              started: started,
              retry_count: attempts,
              http_status: response.status
            )
            return parsed
          rescue ProviderFailure => error
            retrying = retryable?(error, method: method, attempts: attempts, safe_retries: safe_retries)
            emit(
              outcome: retrying ? "retrying" : "failed",
              operation: operation,
              started: started,
              retry_count: attempts,
              http_status: response&.status,
              error_category: error.category
            )
            raise unless retrying

            attempts += 1
            @sleeper.call(retry_delay(error, attempts))
          end
        end
      end

      def perform_request(method:, uri:, body:, correlation_key:, operation:)
        @transport.call(
          method: method,
          uri: uri,
          headers: request_headers(correlation_key),
          body: body,
          open_timeout: @open_timeout,
          read_timeout: @read_timeout,
          write_timeout: @write_timeout,
          max_response_bytes: @max_response_bytes
        )
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error
        raise failure("timeout", operation: operation, retryable: true), cause: nil
      rescue ResponseTooLarge
        raise failure("malformed_response", operation: operation, retryable: false), cause: nil
      rescue SocketError, SystemCallError
        raise failure("unavailable", operation: operation, retryable: true), cause: nil
      end

      def parse_response(response, operation:)
        status = response.status
        if status.between?(200, 299)
          return parse_json(response, operation: operation)
        end

        category, retryable = case status
        when 401 then [ "authentication", false ]
        when 403 then [ "authorization", false ]
        when 404 then [ "not_found", false ]
        when 400, 409, 422 then [ "validation", false ]
        when 429 then [ "rate_limited", true ]
        when 500..599 then [ "unavailable", true ]
        else [ "malformed_response", false ]
        end
        raise failure(
          category,
          operation: operation,
          retryable: retryable,
          retry_after: category == "rate_limited" ? retry_after(response.headers["retry-after"]) : nil
        )
      end

      def parse_json(response, operation:)
        unless JSON_API_RESPONSE.match?(response.headers["content-type"].to_s) &&
            response.body.bytesize <= @max_response_bytes
          raise failure("malformed_response", operation: operation, retryable: false)
        end

        parsed = JSON.parse(response.body, max_nesting: 32)
        raise JSON::ParserError unless parsed.is_a?(Hash)

        deep_freeze(parsed)
      rescue JSON::ParserError, JSON::NestingError
        raise failure("malformed_response", operation: operation, retryable: false), cause: nil
      end

      def endpoint(path)
        uri = URI("#{API_ORIGIN}#{path}")
        valid = uri.scheme == "https" && uri.host == "api.lemonsqueezy.com" && uri.port == 443 &&
          uri.userinfo.nil? && uri.fragment.nil? && uri.path.start_with?("/v1/")
        raise ArgumentError, "billing API endpoint is invalid" unless valid

        uri
      rescue URI::InvalidURIError
        raise ArgumentError, "billing API endpoint is invalid", cause: nil
      end

      def encode_payload(payload)
        return if payload.nil?
        raise ArgumentError, "billing request payload must be an object" unless payload.is_a?(Hash)

        body = JSON.generate(payload)
        raise ArgumentError, "billing request payload is too large" if body.bytesize > MAX_REQUEST_BYTES

        body.freeze
      end

      def request_headers(correlation_key)
        headers = {
          "Accept" => JSON_API_CONTENT_TYPE,
          "Content-Type" => JSON_API_CONTENT_TYPE,
          "Authorization" => "Bearer #{@api_key}"
        }
        headers["X-Request-ID"] = correlation_digest(correlation_key) if correlation_key
        headers.freeze
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, item| deep_freeze(key); deep_freeze(item) }
        when Array
          value.each { |item| deep_freeze(item) }
        end
        value.freeze
      end

      def correlation_digest(value)
        key = ValueNormalization.string!(value, name: "idempotency key", maximum: 200)
        "searchops-#{Digest::SHA256.hexdigest(key).first(32)}".freeze
      end

      def json_api_subscription(reference, attributes)
        raise ArgumentError, "subscription attributes are invalid" unless attributes.is_a?(Hash)

        {
          "data" => {
            "type" => "subscriptions",
            "id" => numeric_reference(reference),
            "attributes" => attributes
          }
        }
      end

      def numeric_reference(value)
        ValueNormalization.string!(
          value, name: "Lemon Squeezy reference", maximum: 19,
          pattern: PlanProviderMapping::LEMON_SQUEEZY_REFERENCE_PATTERN
        )
      end

      def bounded_integer(value, name:, range:)
        integer = Integer(value)
        raise ArgumentError, "#{name} is invalid" unless range.cover?(integer)

        integer
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} is invalid", cause: nil
      end

      def failure(category, operation: "http_request", retryable:, retry_after: nil)
        ProviderFailure.new(
          provider: "lemon_squeezy",
          operation: operation,
          category: category,
          retryable: retryable,
          retry_after: retry_after
        )
      end

      def retryable?(error, method:, attempts:, safe_retries:)
        method == :get && error.retryable? && attempts < safe_retries &&
          (error.retry_after.nil? || error.retry_after <= MAX_RETRY_DELAY)
      end

      def retry_delay(error, attempt)
        error.retry_after || (0.1 * (2**(attempt - 1)))
      end

      def retry_after(value)
        return if value.blank?

        seconds = Integer(value, 10)
        return unless seconds.positive?

        [ seconds, 3600 ].min
      rescue ArgumentError
        begin
          seconds = (Time.httpdate(value) - @clock.call).ceil
          seconds.positive? ? [ seconds, 3600 ].min : nil
        rescue ArgumentError
          nil
        end
      end

      def emit(outcome:, operation:, started:, retry_count:, http_status: nil, error_category: nil)
        @instrumentation.emit(
          outcome: outcome,
          operation: operation,
          duration_ms: ((@monotonic_clock.call - started) * 1000).round(3),
          retry_count: retry_count,
          http_status: http_status,
          error_category: error_category
        )
      end

      def validate_limits!
        valid = [ @open_timeout, @read_timeout, @write_timeout ].all? do |timeout|
          timeout.is_a?(Numeric) && timeout.between?(0.1, 30)
        end
        valid &&= @max_response_bytes.is_a?(Integer) && @max_response_bytes.between?(1024, 1_048_576)
        raise ArgumentError, "billing HTTP client limits are invalid" unless valid
      end
    end
  end
end
