# frozen_string_literal: true

require "digest"
require "json"

module Crawling
  class ScanUsageIdentity
    MAXIMUM_KEY_BYTES = 200

    def digest(source_key)
      key = source_key.to_s
      raise Invalid.new(reason_code: "scan_usage_source_invalid") unless
        key.valid_encoding? && key.bytesize.between?(1, MAXIMUM_KEY_BYTES)

      Digest::SHA256.hexdigest(key)
    end

    def checksum(attributes)
      Digest::SHA256.hexdigest(JSON.generate(normalize(attributes).sort.to_h))
    end

    def metadata(value)
      valid = value.is_a?(Hash) && JSON.generate(value).bytesize <= 2.kilobytes
      raise Invalid.new(reason_code: "scan_usage_metadata_invalid") unless valid

      value.deep_stringify_keys.sort.to_h
    rescue JSON::GeneratorError
      raise Invalid.new(reason_code: "scan_usage_metadata_invalid"), cause: nil
    end

    private

    def normalize(value)
      case value
      when Hash then value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { |item| normalize(item) }
      when Array then value.map { |item| normalize(item) }
      when BigDecimal then value.to_s("F")
      when Time, ActiveSupport::TimeWithZone then value.utc.iso8601(6)
      else value
      end
    end
  end
end
