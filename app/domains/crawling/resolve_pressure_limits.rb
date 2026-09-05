# frozen_string_literal: true

module Crawling
  class ResolvePressureLimits
    DEFAULT_PLAN_SCAN_ALLOWANCE = 1
    DEFAULT_SCAN_RATE = 2.0

    def call(scan:, at: Time.current)
      settings = Rails.application.config.x.searchops
      plan_allowance = plan_scan_allowance(scan)
      global_concurrency = settings.fetch(:crawler_global_fetch_concurrency)
      organization_concurrency = [
        global_concurrency,
        plan_allowance * settings.fetch(:crawler_organization_fetch_concurrency_per_scan)
      ].min
      scan_concurrency = bounded_integer(
        scan.settings_snapshot["max_concurrency"],
        fallback: settings.fetch(:crawler_concurrency),
        maximum: settings.fetch(:crawler_concurrency)
      )
      global_rate = settings.fetch(:crawler_global_request_rate).to_f
      organization_rate = [
        global_rate,
        plan_allowance * settings.fetch(:crawler_organization_request_rate_per_scan)
      ].min
      scan_rate = bounded_rate(
        scan.settings_snapshot["request_rate_per_second"],
        fallback: DEFAULT_SCAN_RATE,
        maximum: 10.0
      )
      started = scan.started_at || scan.queued_at || scan.requested_at || at

      PressureLimits.new(
        global_concurrency: global_concurrency,
        organization_concurrency: organization_concurrency,
        scan_concurrency: [ scan_concurrency, organization_concurrency, global_concurrency ].min,
        host_concurrency: settings.fetch(:crawler_host_fetch_concurrency),
        global_rate: global_rate,
        organization_rate: organization_rate,
        scan_rate: [ scan_rate, organization_rate, global_rate ].min,
        host_rate: settings.fetch(:crawler_host_request_rate),
        permit_duration: settings.fetch(:crawler_fetch_permit_duration),
        scan_deadline: started + settings.fetch(:crawler_scan_max_duration).seconds
      )
    end

    private

    def plan_scan_allowance(scan)
      value = scan.entitlement_snapshot.dig("crawl.concurrent_scans", "organization")
      bounded_integer(value, fallback: DEFAULT_PLAN_SCAN_ALLOWANCE, maximum: 100_000)
    end

    def bounded_integer(value, fallback:, maximum:)
      candidate = Integer(value || fallback)
      raise ArgumentError unless candidate.between?(1, maximum)

      candidate
    rescue ArgumentError, TypeError
      Integer(fallback)
    end

    def bounded_rate(value, fallback:, maximum:)
      candidate = Float(value || fallback)
      raise ArgumentError unless candidate.finite? && candidate.between?(0.1, maximum)

      candidate
    rescue ArgumentError, TypeError
      Float(fallback)
    end
  end
end
