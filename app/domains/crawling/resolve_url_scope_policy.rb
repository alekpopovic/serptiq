# frozen_string_literal: true

module Crawling
  class ResolveUrlScopePolicy
    def call(organization_id:, scan_id:)
      scan = Scan.find_by!(organization_id: organization_id, id: scan_id)
      environment = Properties::Public.environment_reference(
        environment_id: scan.environment_id,
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id
      )
      raise ActiveRecord::RecordNotFound unless environment

      configuration = scan.settings_snapshot.to_h.stringify_keys
      UrlScopePolicy.new(
        origin: environment.origin,
        allowed_hosts: configuration.fetch("allowed_hosts", []),
        include_patterns: configuration.fetch("include_patterns", []),
        exclude_patterns: configuration.fetch("exclude_patterns", []),
        max_depth: configuration.fetch("max_depth", 100),
        query_handling: configuration.fetch("query_handling", "all"),
        query_parameter_allowlist: configuration.fetch("query_parameter_allowlist", []),
        query_parameter_denylist: configuration.fetch("query_parameter_denylist", [])
      )
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "url_scope_unavailable"), cause: nil
    end
  end
end
