# frozen_string_literal: true

module Crawling
  ScanMeterContext = Data.define(:key, :window, :rate, :snapshot) do
    def initialize(**attributes)
      attributes[:key] = attributes.fetch(:key).to_s.dup.freeze
      attributes[:snapshot] = attributes.fetch(:snapshot).freeze
      super(**attributes)
      freeze
    end
  end

  class ResolveScanMeterContext
    METER_KEYS = {
      "http_fetch" => "crawl.http_fetch",
      "rendered_page" => "crawl.rendered_page",
      "lighthouse_page" => "performance.lighthouse_page"
    }.freeze

    def call(scan:, operation_kind:)
      key = METER_KEYS.fetch(operation_kind.to_s)
      raw = scan.entitlement_snapshot.dig("credit_estimate", "meters", key)
      raise Invalid.new(reason_code: "scan_usage_snapshot_invalid") unless raw.is_a?(Hash)

      context = Usage::Public.resolve_meter_snapshot(
        organization_id: scan.organization_id,
        meter_key: key,
        window_id: raw["window_id"],
        meter_definition_id: raw["meter_definition_id"],
        meter_rate_id: raw["meter_rate_id"],
        definition_checksum: raw["definition_checksum"],
        rate_version: raw["version"],
        rate_checksum: raw["rate_checksum"],
        weight: raw["weight"]
      )

      ScanMeterContext.new(key: key, window: context.window, rate: context.rate, snapshot: raw.deep_dup)
    rescue KeyError, ArgumentError, Usage::Public::Invalid
      raise Invalid.new(reason_code: "scan_usage_snapshot_invalid"), cause: nil
    end
  end
end
