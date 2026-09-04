# frozen_string_literal: true

module Usage
  class AggregateQuery
    ZERO = BigDecimal("0").freeze

    def initialize(pool: QuotaPool.new)
      @pool = pool
    end

    def call(organization_id:, window_id:, at: Time.current)
      raise Invalid.new(reason_code: "usage_summary_time_invalid") unless
        at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)

      window = UsageWindow.includes(:meter_definition).find_by(
        id: window_id, organization_id: organization_id
      )
      raise Invalid.new(reason_code: "usage_window_not_found") unless window

      balance = @pool.balance(window: window, at: at)
      limit, unlimited = resolve_limit(window)
      remaining = unlimited ? nil : [ limit - balance.used - balance.reserved, ZERO ].max
      UsageSummary.new(
        organization_id: organization_id,
        window_id: window.id,
        meter_key: window.meter_definition.key,
        pool_key: window.meter_definition.pool_key,
        unit: window.meter_definition.billing_unit,
        used: balance.used,
        reserved: balance.reserved,
        limit: limit,
        remaining: remaining,
        unlimited: unlimited,
        starts_at: window.starts_at,
        ends_at: window.ends_at
      )
    end

    private

    def resolve_limit(window)
      key = window.meter_definition.quota_entitlement_key
      return [ nil, true ] if key.nil?

      normalized = Entitlements::Public.resolve_plan_snapshot(
        plan_version_id: window.plan_version_id,
        entitlement_key: key
      )
      value = normalized&.value
      return [ BigDecimal(value.to_s), false ] if value.is_a?(Integer) && value >= 0

      [ ZERO, false ]
    end
  end
end
