# frozen_string_literal: true

require "digest"

module Crawling
  class ScanSnapshot
    MAX_BYTES = 32.kilobytes
    MAX_DEPTH = 6
    MAX_COLLECTION_SIZE = 100
    MAX_STRING_BYTES = 2.kilobytes
    KEY_PATTERN = /\A[a-z][a-z0-9_.-]{0,63}\z/
    SENSITIVE_KEY_PATTERN = /(authorization|cookie|credential|password|private_key|refresh_token|secret|token)/i

    attr_reader :value, :digest

    def initialize(value:)
      @value = normalize(value, depth: 0)
      serialized = JSON.generate(@value)
      raise ArgumentError, "scan snapshot is too large" if serialized.bytesize > MAX_BYTES

      @digest = Digest::SHA256.hexdigest(serialized).freeze
      freeze
    end

    private

    def normalize(value, depth:)
      raise ArgumentError, "scan snapshot is too deeply nested" if depth > MAX_DEPTH

      case value
      when Hash then normalize_hash(value, depth)
      when Array then normalize_array(value, depth)
      when String then normalize_string(value)
      when Integer, TrueClass, FalseClass, NilClass then value
      when BigDecimal then value.to_s("F").freeze
      when Float
        raise ArgumentError, "scan snapshot number is invalid" unless value.finite?

        value
      else
        raise ArgumentError, "scan snapshot contains an unsupported value"
      end
    end

    def normalize_hash(value, depth)
      raise ArgumentError, "scan snapshot object is too large" if value.size > MAX_COLLECTION_SIZE

      value.to_h { |key, item| [ normalize_key(key), normalize(item, depth: depth + 1) ] }
        .sort.to_h.freeze
    end

    def normalize_array(value, depth)
      raise ArgumentError, "scan snapshot array is too large" if value.size > MAX_COLLECTION_SIZE

      value.map { |item| normalize(item, depth: depth + 1) }.freeze
    end

    def normalize_key(value)
      key = value.to_s
      valid = key.valid_encoding? && KEY_PATTERN.match?(key) && !SENSITIVE_KEY_PATTERN.match?(key)
      raise ArgumentError, "scan snapshot key is invalid" unless valid

      key.freeze
    end

    def normalize_string(value)
      valid = value.valid_encoding? && value.bytesize <= MAX_STRING_BYTES && !value.match?(/[\u0000\r\n]/)
      raise ArgumentError, "scan snapshot string is invalid" unless valid

      value.dup.freeze
    end
  end
end
