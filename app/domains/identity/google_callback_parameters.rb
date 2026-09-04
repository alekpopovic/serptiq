# frozen_string_literal: true

require "uri"

module Identity
  class GoogleCallbackParameters
    MAX_QUERY_BYTES = 8192
    CRITICAL_KEYS = %w[state code error].freeze
    ERROR_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/

    attr_reader :state, :code, :error

    def self.from_query_string(query_string)
      query = query_string.to_s
      raise InvalidOauthTransaction if query.bytesize > MAX_QUERY_BYTES

      pairs = URI.decode_www_form(query, Encoding::UTF_8)
      selected = pairs.select { |key, _value| CRITICAL_KEYS.include?(key) }
      counts = selected.each_with_object(Hash.new(0)) { |(key, _value), memo| memo[key] += 1 }
      raise InvalidOauthTransaction if counts.any? { |_key, count| count > 1 }

      values = selected.to_h
      new(state: values["state"], code: values["code"], error: values["error"])
    rescue ArgumentError, EncodingError
      raise InvalidOauthTransaction, cause: nil
    end

    def initialize(state:, code:, error:)
      @state = state.to_s.dup.freeze
      @code = code&.to_s&.dup&.freeze
      @error = error&.to_s&.dup&.freeze
      raise InvalidOauthTransaction unless OauthAuthorizationSecrets::STATE_PATTERN.match?(@state)

      freeze
    end

    def authorization_code!
      valid = code && CallbackInput::CODE_PATTERN.match?(code) && error.nil?
      raise malformed("google_callback_parameters_invalid") unless valid

      code
    end

    def raise_provider_error!
      return unless error
      raise malformed("google_authorization_error_invalid") unless ERROR_PATTERN.match?(error) && code.nil?

      case error
      when "access_denied"
        raise ProviderError.new(
          category: "access_denied",
          operation: "authorization_response",
          reason_code: "google_authorization_denied"
        )
      when "server_error", "temporarily_unavailable"
        raise ProviderError.new(
          category: "unavailable",
          operation: "authorization_response",
          reason_code: "google_authorization_unavailable"
        )
      else
        raise malformed("google_authorization_error_unknown")
      end
    end

    def inspect
      "#<#{self.class.name} state=[FILTERED] code=#{code ? '[FILTERED]' : 'nil'} " \
        "error=#{error.inspect}>"
    end

    private

    def malformed(reason_code)
      ProviderError.new(category: "malformed_response", operation: "authorization_response", reason_code: reason_code)
    end
  end
end
