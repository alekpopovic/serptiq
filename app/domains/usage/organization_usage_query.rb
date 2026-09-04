# frozen_string_literal: true

module Usage
  class OrganizationUsageQuery
    ZERO = BigDecimal("0").freeze

    def initialize(authorizer: UsageDashboardAuthorizer.new, aggregate_query: AggregateQuery.new)
      @authorizer = authorizer
      @aggregate_query = aggregate_query
    end

    def call(organization_id:, authorization:, at: Time.current)
      validate_time!(at)
      @authorizer.call(organization_id: organization_id, authorization: authorization)
      definitions = MeterDefinition.includes(:rates).order(:pool_key, :key).to_a
      windows = UsageWindow.covering(at).where(organization_id: organization_id)
        .index_by(&:usage_meter_definition_id)
      entries = definitions.group_by { |definition| pool_identity(definition) }.values.map do |pool_definitions|
        build_entry(
          organization_id: organization_id,
          definitions: pool_definitions,
          windows: windows,
          at: at
        )
      end
      UsageDashboard.new(organization_id: organization_id, entries: entries, generated_at: at)
    end

    private

    def validate_time!(at)
      return if at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)

      raise Invalid.new(reason_code: "usage_dashboard_time_invalid")
    end

    def pool_identity(definition)
      [
        definition.pool_key,
        definition.billing_unit,
        definition.quota_entitlement_key,
        definition.window_policy
      ]
    end

    def build_entry(organization_id:, definitions:, windows:, at:)
      window = definitions.filter_map { |definition| windows[definition.id] }.min_by(&:id)
      return entry_from_summary(definitions, organization_id, window, at) if window

      entry_without_window(definitions, organization_id, at)
    end

    def entry_from_summary(definitions, organization_id, window, at)
      summary = @aggregate_query.call(organization_id: organization_id, window_id: window.id, at: at)
      state = if summary.unlimited?
        "unlimited"
      elsif summary.limit.zero?
        "disabled"
      elsif summary.remaining.zero?
        "exhausted"
      elsif summary.reserved.positive?
        "temporarily_reserved"
      else
        "available"
      end
      dashboard_entry(
        definitions,
        state: state,
        used: summary.used,
        reserved: summary.reserved,
        limit: summary.limit,
        remaining: summary.remaining,
        starts_at: summary.starts_at,
        reset_at: summary.ends_at,
        reason_code: nil
      )
    end

    def entry_without_window(definitions, organization_id, at)
      key = definitions.first.quota_entitlement_key
      return dashboard_entry(
        definitions,
        state: "unlimited",
        used: ZERO,
        reserved: ZERO,
        limit: nil,
        remaining: nil,
        starts_at: nil,
        reset_at: nil,
        reason_code: "usage_unlimited"
      ) if key.nil?

      resolution = Entitlements::Public.resolve(
        organization_id: organization_id,
        entitlement_key: key,
        at: at
      )
      value = resolution.value
      if value.is_a?(Integer) && value >= 0
        limit = BigDecimal(value.to_s)
        dashboard_entry(
          definitions,
          state: limit.zero? ? "disabled" : "available",
          used: ZERO,
          reserved: ZERO,
          limit: limit,
          remaining: limit,
          starts_at: nil,
          reset_at: nil,
          reason_code: resolution.reason_code
        )
      else
        dashboard_entry(
          definitions,
          state: "unavailable",
          used: ZERO,
          reserved: ZERO,
          limit: nil,
          remaining: nil,
          starts_at: nil,
          reset_at: nil,
          reason_code: resolution.reason_code
        )
      end
    end

    def dashboard_entry(definitions, **attributes)
      definition = definitions.first
      UsageDashboardEntry.new(
        pool_key: definition.pool_key,
        unit: definition.billing_unit,
        meters: definitions.map { |meter| explanation(meter, attributes.fetch(:starts_at) || Time.current) },
        **attributes
      )
    end

    def explanation(definition, at)
      current_rate = definition.rates.select { |rate| rate.effective_at <= at }.max_by(&:effective_at)
      UsageMeterExplanation.new(
        key: definition.key,
        name: definition.name,
        description: definition.description,
        weight: current_rate&.weight,
        source_unit: definition.unit
      )
    end
  end
end
