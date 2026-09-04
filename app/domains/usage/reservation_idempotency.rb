# frozen_string_literal: true

require "digest"
require "json"

module Usage
  class ReservationIdempotency
    MAX_KEY_BYTES = 200

    def digest(raw)
      key = raw.to_s
      raise Invalid.new(reason_code: "usage_reservation_idempotency_invalid") unless
        key.valid_encoding? && key.bytesize.between?(1, MAX_KEY_BYTES)

      Digest::SHA256.hexdigest(key)
    end

    def checksum(attributes)
      normalized = attributes.transform_values { |value| normalize(value) }
      Digest::SHA256.hexdigest(JSON.generate(normalized.sort.to_h))
    end

    private

    def normalize(value)
      case value
      when BigDecimal then value.to_s("F")
      when Time, ActiveSupport::TimeWithZone then value.utc.iso8601(6)
      when Hash then value.sort.to_h.transform_values { |item| normalize(item) }
      when Array then value.map { |item| normalize(item) }
      else value
      end
    end
  end
end
