# frozen_string_literal: true

module TestSupport
  module CrawlPolicyHelpers
    CRAWL_ENTITLEMENTS = {
      "crawl.manual" => [ "boolean", true ],
      "crawl.max_urls_per_scan" => [ "integer", 500 ],
      "crawl.concurrent_scans" => [ "integer", 2 ],
      "crawl.javascript_rendering" => [ "boolean", true ],
      "crawl.max_rendered_pages_per_scan" => [ "integer", 10 ],
      "crawl.custom_user_agent" => [ "boolean", true ],
      "crawl.custom_rules" => [ "boolean", true ],
      "data.raw_artifact_retention_days" => [ "integer", 14 ]
    }.freeze

    def enable_crawl_policy(result, values: {}, at: Time.current)
      Plans::Public.sync_catalog
      Entitlements::Public.sync_catalog
      CRAWL_ENTITLEMENTS.merge(values).each do |key, (type, value)|
        definition = Entitlements::Definition.find_by!(key: key)
        Entitlements::OrganizationOverride.create!(
          organization_id: result.organization.id,
          entitlement_definition_id: definition.id,
          value_type: type,
          value: value,
          starts_at: at - 1.minute,
          reason: "Crawl policy test capability",
          source: "support",
          created_by_membership_id: result.membership.id
        )
      end
      Current.entitlement_cache = nil
    end

    def valid_crawl_policy_attributes(origin:, **overrides)
      {
        start_urls: "#{origin}/\n#{origin}/docs?utm_source=test",
        sitemap_urls: "#{origin}/sitemap.xml",
        include_patterns: "/docs/**\n/products/*",
        exclude_patterns: "/private/**",
        max_urls: 20,
        max_depth: 5,
        query_handling: "tracking_only",
        query_parameter_allowlist: "",
        query_parameter_denylist: "session_id",
        user_agent_suffix: "AcmeAudit",
        request_rate_per_second: "2.5",
        max_concurrency: 1,
        robots_behavior: "respect",
        rendering_sample_percent: 20,
        max_rendered_pages: 4,
        artifact_retention_days: 7
      }.merge(overrides)
    end
  end
end
