# frozen_string_literal: true

module Crawling
  class ResolveConcurrentScanLimits
    ENTITLEMENT_KEY = "crawl.concurrent_scans"

    def initialize(resolver: ->(**attributes) { Entitlements::Public.resolve(**attributes) })
      @resolver = resolver
    end

    def call(organization_id:, at: Time.current)
      resolution = @resolver.call(
        organization_id: organization_id,
        entitlement_key: ENTITLEMENT_KEY,
        at: at
      )
      organization_limit = resolution.value
      unless resolution.enabled? && organization_limit.is_a?(Integer) && organization_limit.positive?
        raise CapacityExceeded.new(scope: "organization", reason_code: "scan_capacity_unavailable")
      end

      settings = Rails.application.config.x.searchops
      ConcurrentScanLimits.new(
        organization: organization_limit,
        project: [ organization_limit, settings.fetch(:crawler_project_concurrent_scans) ].min,
        global: settings.fetch(:crawler_global_concurrent_scans),
        provenance: resolution.provenance
      )
    end
  end
end
