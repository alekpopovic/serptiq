# frozen_string_literal: true

require "json"
require "uri"

module Billing
  module ValueNormalization
    PROVIDER_PATTERN = /\A[a-z][a-z0-9_]{1,31}\z/
    REFERENCE_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9_.:-]{0,190}\z/
    KEY_PATTERN = /\A[a-z][a-z0-9_.-]{0,63}\z/
    EMAIL_PATTERN = /\A[^\s@]+@[^\s@]+\z/
    MAX_METADATA_BYTES = 4096
    FILTERED = "[FILTERED]"

    module_function

    def string!(value, name:, maximum:, pattern: nil)
      normalized = value.to_s
      valid = normalized.valid_encoding? && normalized == normalized.strip &&
        normalized.bytesize.between?(1, maximum) && (!pattern || pattern.match?(normalized))
      raise ArgumentError, "#{name} is invalid" unless valid

      normalized.freeze
    end

    def optional_string(value, name:, maximum:, pattern: nil)
      return if value.nil?

      string!(value, name: name, maximum: maximum, pattern: pattern)
    end

    def uuid!(value, name:)
      normalized = value.to_s
      raise ArgumentError, "#{name} is invalid" unless Shared::Public.application_uuid?(normalized)

      normalized.freeze
    end

    def time!(value, name:, optional: false)
      return if optional && value.nil?
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      raise ArgumentError, "#{name} is invalid"
    end

    def url!(value, name:)
      uri = URI.parse(value.to_s)
      valid = uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.fragment.nil?
      raise ArgumentError, "#{name} is invalid" unless valid

      uri.to_s.freeze
    rescue URI::InvalidURIError
      raise ArgumentError, "#{name} is invalid", cause: nil
    end

    def metadata(value)
      normalized = deep_normalize(value, depth: 0)
      raise ArgumentError, "metadata must be an object" unless normalized.is_a?(Hash)
      raise ArgumentError, "metadata is too large" if JSON.generate(normalized).bytesize > MAX_METADATA_BYTES

      normalized.freeze
    end

    def redacted(value)
      value.nil? ? nil : FILTERED
    end

    def safe_inspect(object)
      "#<#{object.class.name} #{object.as_json.inspect}>"
    end

    def deep_normalize(value, depth:)
      raise ArgumentError, "metadata is too deeply nested" if depth > 3

      case value
      when Hash
        raise ArgumentError, "metadata has too many fields" if value.size > 32

        value.to_h do |key, item|
          normalized_key = string!(key, name: "metadata key", maximum: 64, pattern: KEY_PATTERN)
          [ normalized_key, deep_normalize(item, depth: depth + 1) ]
        end.freeze
      when Array
        raise ArgumentError, "metadata array is too large" if value.size > 32

        value.map { |item| deep_normalize(item, depth: depth + 1) }.freeze
      when String
        string!(value, name: "metadata value", maximum: 256)
      when Integer, TrueClass, FalseClass, NilClass
        value
      when BigDecimal
        value.to_s("F").freeze
      else
        raise ArgumentError, "metadata contains an unsupported value"
      end
    end
    private_class_method :deep_normalize
  end
end
