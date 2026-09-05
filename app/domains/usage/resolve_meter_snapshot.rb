# frozen_string_literal: true

module Usage
  class ResolveMeterSnapshot
    def call(organization_id:, meter_key:, window_id:, meter_definition_id:, meter_rate_id:,
      definition_checksum:, rate_version:, rate_checksum:, weight:)
      window = UsageWindow.includes(:meter_definition).find_by(
        id: window_id,
        organization_id: organization_id,
        usage_meter_definition_id: meter_definition_id
      )
      rate = ResolveExactMeterRate.new.call(
        window: window,
        version: rate_version,
        catalog_checksum: rate_checksum
      ) if window
      valid = window && rate && window.meter_definition.key == meter_key.to_s &&
        window.meter_definition.catalog_checksum == definition_checksum.to_s &&
        rate.id.to_s == meter_rate_id.to_s && rate.weight == BigDecimal(weight.to_s)
      raise Invalid.new(reason_code: "usage_meter_snapshot_invalid") unless valid

      MeterContext.new(window: window, rate: rate)
    rescue ArgumentError, Invalid
      raise Invalid.new(reason_code: "usage_meter_snapshot_invalid"), cause: nil
    end
  end
end
