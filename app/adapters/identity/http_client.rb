# frozen_string_literal: true

require "json"
require "net/http"
require "set"
require "time"
require "uri"

module Identity
  class HttpClient
    SAFE_RETRY_OPERATIONS = %w[discovery jwks].freeze
    JSON_CONTENT_TYPE = %r{\Aapplication/(?:[a-z0-9.+-]+\+)?json(?:\s*;|\z)}i
    MAX_RETRY_DELAY = 2.0

    def self.from_settings(configuration:, settings: Rails.application.config.x.searchops,
      transport: NetHttpTransport.new, sleeper: ->(delay) { sleep(delay) }, clock: -> { Time.now })
      new(
        allowed_endpoints: configuration.endpoint_uris,
        open_timeout: settings.fetch(:oauth_http_open_timeout),
        read_timeout: settings.fetch(:oauth_http_read_timeout),
        max_response_bytes: settings.fetch(:oauth_http_max_response_bytes),
        safe_retries: settings.fetch(:oauth_http_safe_retries),
        transport: transport,
        sleeper: sleeper,
        clock: clock
      )
    end

    def initialize(allowed_endpoints:, open_timeout:, read_timeout:, max_response_bytes:, safe_retries:,
      transport:, sleeper:, clock:)
      @allowed_endpoints = allowed_endpoints.map(&:to_s).to_set.freeze
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @max_response_bytes = max_response_bytes
      @safe_retries = safe_retries
      @transport = transport
      @sleeper = sleeper
      @clock = clock
      validate_limits!
    end

    def get_json(uri:, operation:, headers: {})
      request_json(method: :get, uri: uri, operation: operation, headers: headers, body: nil, expected: :object)
    end

    def get_json_array(uri:, operation:, headers: {}, max_items:)
      unless max_items.is_a?(Integer) && max_items.between?(1, 100)
        raise ArgumentError, "JSON array item limit is invalid"
      end

      request_json(
        method: :get,
        uri: uri,
        operation: operation,
        headers: headers,
        body: nil,
        expected: :array,
        max_items: max_items
      )
    end

    def post_form_json(uri:, operation:, form:, headers: {})
      body = URI.encode_www_form(form)
      request_json(
        method: :post,
        uri: uri,
        operation: operation,
        headers: { "Content-Type" => "application/x-www-form-urlencoded" }.merge(headers),
        body: body,
        expected: :object
      )
    end

    private

    def request_json(method:, uri:, operation:, headers:, body:, expected:, max_items: nil)
      uri = validate_endpoint!(uri)
      attempts = 0

      loop do
        response = perform_request(method: method, uri: uri, headers: headers, body: body, operation: operation)
        return parse_response(response, operation: operation, expected: expected, max_items: max_items)
      rescue ProviderError => error
        raise unless retryable?(error, method: method, operation: operation, attempts: attempts)

        attempts += 1
        @sleeper.call(retry_delay(error, attempts))
      end
    end

    def perform_request(method:, uri:, headers:, body:, operation:)
      @transport.call(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
        open_timeout: @open_timeout,
        read_timeout: @read_timeout,
        max_response_bytes: @max_response_bytes
      )
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
      raise ProviderError.new(category: "timeout", operation: operation), cause: nil
    rescue ResponseTooLarge
      raise ProviderError.new(category: "malformed_response", operation: operation,
        reason_code: "provider_response_too_large"), cause: nil
    rescue SocketError, SystemCallError
      raise ProviderError.new(category: "unavailable", operation: operation), cause: nil
    end

    def parse_response(response, operation:, expected:, max_items:)
      status = response.status
      return parse_json(response, operation: operation, expected: expected, max_items: max_items) if status.between?(200, 299)

      case status
      when 401
        raise ProviderError.new(category: "credentials_revoked", operation: operation)
      when 403
        if rate_limited_response?(response)
          raise ProviderError.new(
            category: "rate_limited",
            operation: operation,
            retry_after: parse_retry_after(response.headers["retry-after"])
          )
        end
        raise ProviderError.new(category: "credentials_revoked", operation: operation)
      when 429
        raise ProviderError.new(
          category: "rate_limited",
          operation: operation,
          retry_after: parse_retry_after(response.headers["retry-after"])
        )
      when 500..599
        raise ProviderError.new(category: "unavailable", operation: operation)
      else
        raise ProviderError.new(category: "access_denied", operation: operation)
      end
    end

    def parse_json(response, operation:, expected:, max_items:)
      content_type = response.headers["content-type"].to_s
      unless JSON_CONTENT_TYPE.match?(content_type) && response.body.bytesize <= @max_response_bytes
        raise ProviderError.new(category: "malformed_response", operation: operation)
      end

      parsed = JSON.parse(response.body, max_nesting: 32)
      return parsed.freeze if expected == :object && parsed.is_a?(Hash)
      if expected == :array && parsed.is_a?(Array) && parsed.length <= max_items && parsed.all?(Hash)
        return parsed.each(&:freeze).freeze
      end

      raise ProviderError.new(category: "malformed_response", operation: operation)
    rescue JSON::ParserError, JSON::NestingError
      raise ProviderError.new(category: "malformed_response", operation: operation), cause: nil
    end

    def validate_endpoint!(value)
      uri = value.is_a?(URI::Generic) ? value : URI.parse(value.to_s)
      unless uri.scheme == "https" && uri.userinfo.nil? && @allowed_endpoints.include?(uri.to_s)
        raise ProviderError.new(
          category: "configuration",
          operation: "http_request",
          reason_code: "provider_endpoint_not_allowlisted"
        )
      end
      uri
    rescue URI::InvalidURIError
      raise ProviderError.new(
        category: "configuration",
        operation: "http_request",
        reason_code: "provider_endpoint_invalid"
      ), cause: nil
    end

    def retryable?(error, method:, operation:, attempts:)
      method == :get && SAFE_RETRY_OPERATIONS.include?(operation.to_s) && error.retryable? &&
        attempts < @safe_retries && (error.retry_after.nil? || error.retry_after <= MAX_RETRY_DELAY)
    end

    def retry_delay(error, attempt)
      error.retry_after || (0.1 * (2**(attempt - 1)))
    end

    def validate_limits!
      valid = @allowed_endpoints.any? && @open_timeout.is_a?(Numeric) && @open_timeout.positive? &&
        @read_timeout.is_a?(Numeric) && @read_timeout.positive? && @max_response_bytes.is_a?(Integer) &&
        @max_response_bytes.positive? && @safe_retries.is_a?(Integer) && @safe_retries.between?(0, 3)
      raise ArgumentError, "HTTP client limits are invalid" unless valid
    end

    def parse_retry_after(value)
      return if value.blank?

      seconds = Integer(value, 10)
      return unless seconds >= 0

      [ seconds, 3600 ].min
    rescue ArgumentError
      begin
        timestamp = Time.httpdate(value)
        [ [ timestamp - @clock.call, 0 ].max, 3600 ].min
      rescue ArgumentError
        nil
      end
    end

    def rate_limited_response?(response)
      response.headers["x-ratelimit-remaining"] == "0" || response.headers["retry-after"].present?
    end
  end
end
