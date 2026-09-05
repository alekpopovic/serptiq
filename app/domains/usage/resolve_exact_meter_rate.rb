# frozen_string_literal: true

module Usage
  class ResolveExactMeterRate
    def call(window:, version:, catalog_checksum:)
      valid = window.is_a?(UsageWindow) && window.persisted? &&
        version.is_a?(Integer) && version.positive? &&
        UsageEvent::DIGEST_PATTERN.match?(catalog_checksum.to_s)
      raise Invalid.new(reason_code: "usage_meter_rate_snapshot_invalid") unless valid

      rate = MeterRate.find_by(
        usage_meter_definition_id: window.usage_meter_definition_id,
        version: version,
        catalog_checksum: catalog_checksum
      )
      raise Invalid.new(reason_code: "usage_meter_rate_snapshot_unavailable") unless rate

      rate
    end
  end
end
