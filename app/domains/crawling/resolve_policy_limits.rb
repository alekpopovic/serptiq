# frozen_string_literal: true

module Crawling
  class ResolvePolicyLimits
    MAX_DEPTH = 20
    MAX_REQUEST_RATE = BigDecimal("10.0")

    ENTITLEMENTS = {
      max_urls: "crawl.max_urls_per_scan",
      rendering_enabled: "crawl.javascript_rendering",
      max_rendered_pages: "crawl.max_rendered_pages_per_scan",
      custom_user_agent: "crawl.custom_user_agent",
      custom_patterns: "crawl.custom_rules",
      artifact_retention_days: "data.raw_artifact_retention_days"
    }.freeze

    def initialize(resolver: ->(**attributes) { Entitlements::Public.resolve(**attributes) })
      @resolver = resolver
    end

    def call(organization_id:, at: Time.current)
      resolved = ENTITLEMENTS.transform_values do |key|
        @resolver.call(organization_id: organization_id, entitlement_key: key, at: at)
      end
      PolicyLimits.new(
        max_urls: [ configured_integer!(resolved.fetch(:max_urls)), global(:crawler_max_urls_per_scan) ].min,
        max_depth: MAX_DEPTH,
        max_concurrency: global(:crawler_concurrency),
        max_request_rate: MAX_REQUEST_RATE,
        rendering_enabled: enabled_boolean?(resolved.fetch(:rendering_enabled)),
        max_rendered_pages: configured_integer!(resolved.fetch(:max_rendered_pages), allow_zero: true),
        custom_user_agent: enabled_boolean?(resolved.fetch(:custom_user_agent)),
        custom_patterns: enabled_boolean?(resolved.fetch(:custom_patterns)),
        robots_override: enabled_boolean?(resolved.fetch(:custom_patterns)),
        artifact_retention_days: configured_integer!(
          resolved.fetch(:artifact_retention_days), allow_zero: true
        ),
        provenance: resolved.transform_values(&:provenance)
      )
    end

    private

    def configured_integer!(resolution, allow_zero: false)
      value = resolution.value
      minimum = allow_zero ? 0 : 1
      return value if resolution.enabled? && value.is_a?(Integer) && value >= minimum
      return 0 if allow_zero && resolution.disabled? && value == 0

      raise Invalid.new(
        reason_code: resolution.reason_code,
        field_errors: { base: "An effective numeric crawl limit is not configured." }
      )
    end

    def enabled_boolean?(resolution)
      resolution.enabled? && resolution.value == true
    end

    def global(key)
      Rails.application.config.x.searchops.fetch(key)
    end
  end
end
