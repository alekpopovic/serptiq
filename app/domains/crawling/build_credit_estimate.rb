# frozen_string_literal: true

module Crawling
  class BuildCreditEstimate
    METER_KEYS = %w[
      crawl.http_fetch crawl.rendered_page performance.lighthouse_page
    ].freeze

    def call(configuration:, at: Time.current)
      catalog = Usage::Public.validate_catalog
      rates = catalog.meters.select { |meter| METER_KEYS.include?(meter.key) }.to_h do |meter|
        rate = meter.rates.select { |candidate| candidate.effective_at <= at }.max_by(&:effective_at)
        raise Invalid.new(reason_code: "scan_usage_snapshot_invalid") unless rate

        [ meter.key, MeterRateSnapshot.new(
          key: meter.key,
          definition_checksum: meter.catalog_checksum,
          version: rate.version,
          weight: rate.weight,
          effective_at: rate.effective_at,
          rate_checksum: rate.catalog_checksum
        ) ]
      end
      raise Invalid.new(reason_code: "scan_usage_snapshot_invalid") unless rates.keys == METER_KEYS

      http_weight = rates.fetch("crawl.http_fetch").weight
      rendered_weight = rates.fetch("crawl.rendered_page").weight
      rendered_pages = configuration.max_rendered_pages
      maximum = configuration.max_urls * http_weight + rendered_pages * rendered_weight
      CreditEstimate.new(
        http_pages: configuration.max_urls,
        rendered_pages: rendered_pages,
        http_weight: http_weight,
        rendered_weight: rendered_weight,
        maximum_credits: maximum,
        catalog_version: catalog.version,
        catalog_checksum: catalog.checksum,
        meter_rates: rates
      )
    end
  end
end
