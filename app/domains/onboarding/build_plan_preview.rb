# frozen_string_literal: true

module Onboarding
  class BuildPlanPreview
    LIMITS = {
      projects: [ "projects.max", "projects" ],
      website_properties: [ "website_properties.max", "properties" ],
      mobile_properties: [ "mobile_properties.max", "properties" ]
    }.freeze

    def initialize(access: Access.new, resolver: ->(**attributes) { Entitlements::Public.resolve(**attributes) })
      @access = access
      @resolver = resolver
    end

    def call(actor_membership:, organization_id:, at: Time.current)
      @access.authorize!(actor_membership: actor_membership, organization_id: organization_id)
      property_counts = Properties::Public.active_counts(organization_id: organization_id)
      PlanPreview.new(
        projects: limit(
          :projects, organization_id,
          Projects::Public.active_count(organization_id: organization_id), at
        ),
        website_properties: limit(
          :website_properties, organization_id, property_counts.website, at
        ),
        mobile_properties: limit(
          :mobile_properties, organization_id, property_counts.mobile, at
        ),
        crawl_max_urls: resolution(organization_id, "crawl.max_urls_per_scan", at),
        manual_crawl_enabled: enabled_boolean?(organization_id, "crawl.manual", at),
        rendering_enabled: enabled_boolean?(organization_id, "crawl.javascript_rendering", at)
      )
    end

    private

    def limit(name, organization_id, current, at)
      key, unit = LIMITS.fetch(name)
      value = resolution(organization_id, key, at)
      LimitImpact.new(
        entitlement_key: key,
        state: value.state,
        current: current,
        limit: value.enabled? && value.value.is_a?(Integer) ? value.value : nil,
        unit: unit
      )
    end

    def resolution(organization_id, key, at)
      @resolver.call(organization_id: organization_id, entitlement_key: key, at: at)
    end

    def enabled_boolean?(organization_id, key, at)
      value = resolution(organization_id, key, at)
      value.enabled? && value.value == true
    end
  end
end
