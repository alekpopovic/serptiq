# frozen_string_literal: true

module Integrations
  class DashboardReadinessQuery
    def call(organization_id:, authorization:)
      authorize!(organization_id, authorization)
      counts = Connection.where(
        organization_id: organization_id,
        provider: "search_console"
      ).group(:state).count

      if counts.values_at("connected", "healthy").compact.sum.positive?
        readiness("connected", "Connected", "A usable Search Console connection is present.", counts)
      elsif counts.fetch("degraded", 0).positive?
        readiness("degraded", "Needs attention", "The Search Console provider reported degraded health.", counts)
      elsif counts.fetch("reauthorization_required", 0).positive?
        readiness(
          "reauthorization_required", "Reconnect required",
          "The Search Console connection requires renewed consent.", counts
        )
      else
        readiness(
          "not_connected", "Not connected",
          "Search Console is optional for a baseline crawl and can be connected later.", counts
        )
      end
    end

    private

    def authorize!(organization_id, authorization)
      valid = authorization&.allow? && authorization.permission_key == "integrations.read" &&
        authorization.organization_id.to_s == organization_id.to_s &&
        authorization.scope_type == "Organization" &&
        authorization.scope_id.to_s == organization_id.to_s
      raise AccessDenied unless valid
    end

    def readiness(state, label, detail, counts)
      DashboardReadiness.new(
        state: state,
        label: label,
        detail: detail,
        connection_count: counts.values.sum
      )
    end
  end
end
