# frozen_string_literal: true

require "json"

module Usage
  class Metadata
    MAX_BYTES = 2.kilobytes
    MAX_ENTRIES = 20
    MAX_DEPTH = 2
    MAX_STRING_BYTES = 128
    KEY_PATTERN = /\A[a-z][a-z0-9_]{0,47}\z/
    SENSITIVE_KEY_PATTERN = /(?:body|cookie|credential|email|html|ip|key|payload|secret|signature|token|user_agent)/i

    def call(raw)
      source = raw.nil? ? {} : raw
      raise Invalid.new(reason_code: "usage_metadata_invalid") unless source.is_a?(Hash)

      normalized = normalize_hash(source, depth: 0)
      raise Invalid.new(reason_code: "usage_metadata_invalid") if JSON.generate(normalized).bytesize > MAX_BYTES

      deep_freeze(normalized)
    rescue EncodingError, JSON::GeneratorError
      raise Invalid.new(reason_code: "usage_metadata_invalid"), cause: nil
    end

    private

    def normalize_hash(value, depth:)
      raise Invalid.new(reason_code: "usage_metadata_invalid") if
        depth > MAX_DEPTH || value.length > MAX_ENTRIES

      value.to_h do |key, item|
        normalized_key = key.to_s
        raise Invalid.new(reason_code: "usage_metadata_invalid") unless
          KEY_PATTERN.match?(normalized_key) && !SENSITIVE_KEY_PATTERN.match?(normalized_key)

        [ normalized_key, normalize_value(item, depth: depth + 1) ]
      end
    end

    def normalize_value(value, depth:)
      case value
      when String
        raise Invalid.new(reason_code: "usage_metadata_invalid") unless
          value.valid_encoding? && value.bytesize <= MAX_STRING_BYTES
        value.dup
      when Integer, TrueClass, FalseClass, NilClass
        value
      when BigDecimal
        value.to_s("F")
      when Array
        raise Invalid.new(reason_code: "usage_metadata_invalid") if
          depth > MAX_DEPTH || value.length > MAX_ENTRIES
        value.map { |item| normalize_value(item, depth: depth + 1) }
      when Hash
        normalize_hash(value, depth: depth)
      else
        raise Invalid.new(reason_code: "usage_metadata_invalid")
      end
    end

    def deep_freeze(value)
      case value
      when Hash
        value.each { |key, item| key.freeze && deep_freeze(item) }
      when Array
        value.each { |item| deep_freeze(item) }
      end
      value.freeze
    end
  end
end
