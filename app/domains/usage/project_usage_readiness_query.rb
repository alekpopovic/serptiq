# frozen_string_literal: true

module Usage
  class ProjectUsageReadinessQuery
    ZERO = BigDecimal("0").freeze
    POOL_KEY = "crawl.credits"
    ENTITLEMENT_KEY = "crawl.credits_monthly"

    def initialize(aggregate_query: AggregateQuery.new)
      @aggregate_query = aggregate_query
    end

    def call(organization_id:, project_id:, authorization:, at: Time.current)
      authorize!(organization_id, project_id, authorization)
      validate_time!(at)
      window = current_window(organization_id, at)
      return from_summary(project_id, @aggregate_query.call(
        organization_id: organization_id, window_id: window.id, at: at
      )) if window

      from_entitlement(organization_id, project_id, at)
    end

    private

    def authorize!(organization_id, project_id, authorization)
      valid = authorization&.allow? && authorization.permission_key == "usage.read" &&
        authorization.organization_id.to_s == organization_id.to_s &&
        authorization.scope_type == "Project" && authorization.scope_id.to_s == project_id.to_s
      raise AccessDenied.new(reason_code: "usage_dashboard_forbidden") unless valid
    end

    def validate_time!(at)
      return if at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)

      raise Invalid.new(reason_code: "usage_dashboard_time_invalid")
    end

    def current_window(organization_id, at)
      UsageWindow.covering(at).joins(:meter_definition).find_by(
        organization_id: organization_id,
        usage_meter_definitions: { pool_key: POOL_KEY }
      )
    end

    def from_summary(project_id, summary)
      state = if summary.remaining&.zero?
        "exhausted"
      elsif summary.reserved.positive?
        "temporarily_reserved"
      else
        "available"
      end
      ProjectUsageReadiness.new(
        project_id: project_id,
        state: state,
        used: summary.used,
        reserved: summary.reserved,
        limit: summary.limit,
        remaining: summary.remaining,
        reset_at: summary.ends_at,
        reason_code: nil
      )
    end

    def from_entitlement(organization_id, project_id, at)
      resolution = Entitlements::Public.resolve(
        organization_id: organization_id,
        entitlement_key: ENTITLEMENT_KEY,
        at: at
      )
      value = resolution.value
      if value.is_a?(Integer) && value >= 0
        limit = BigDecimal(value.to_s)
        ProjectUsageReadiness.new(
          project_id: project_id,
          state: limit.zero? ? "disabled" : "available",
          used: ZERO,
          reserved: ZERO,
          limit: limit,
          remaining: limit,
          reset_at: nil,
          reason_code: resolution.reason_code
        )
      else
        ProjectUsageReadiness.new(
          project_id: project_id,
          state: "unavailable",
          used: ZERO,
          reserved: ZERO,
          limit: nil,
          remaining: nil,
          reset_at: nil,
          reason_code: resolution.reason_code
        )
      end
    end
  end
end
