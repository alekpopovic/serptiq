# frozen_string_literal: true

require "digest"

module Usage
  class WindowResolver
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, meter_key:, at: @clock.call, billing_period: nil)
      validate_input!(organization_id, at)
      definition = MeterDefinition.find_by(key: meter_key.to_s)
      raise Invalid.new(reason_code: "usage_meter_unknown") unless definition

      period = resolve_period(definition, at, billing_period)
      context = Entitlements::Public.active_subscription_context(organization_id: organization_id)
      if definition.window_policy == "provider_billing_period" && context.nil?
        raise Invalid.new(reason_code: "usage_subscription_context_required")
      end
      attributes = window_attributes(organization_id, definition, context, period)
      UsageWindow.find_by(attributes.slice(
        :organization_id, :usage_meter_definition_id, :starts_at, :ends_at
      )) || UsageWindow.create!(attributes)
    rescue ActiveRecord::RecordNotUnique
      UsageWindow.find_by!(attributes.slice(
        :organization_id, :usage_meter_definition_id, :starts_at, :ends_at
      ))
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordInvalid => error
      raise Conflict.new(reason_code: "usage_window_invalid"), cause: error
    end

    private

    Period = Data.define(:starts_at, :ends_at, :time_zone_name, :reference_digest)

    def validate_input!(organization_id, at)
      valid_time = at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)
      raise Invalid.new(reason_code: "usage_window_input_invalid") unless
        Shared::Public.application_uuid?(organization_id) && valid_time
    end

    def resolve_period(definition, at, billing_period)
      if definition.window_policy == "utc_calendar_month"
        raise Invalid.new(reason_code: "usage_window_policy_mismatch") if billing_period

        start = Time.utc(at.utc.year, at.utc.month, 1)
        return Period.new(start, start.next_month, "UTC", nil)
      end
      raise Invalid.new(reason_code: "usage_billing_period_required") unless
        billing_period.is_a?(BillingPeriod) && billing_period.cover?(at)

      Period.new(
        billing_period.starts_at, billing_period.ends_at, billing_period.time_zone_name,
        Digest::SHA256.hexdigest(billing_period.reference)
      )
    end

    def window_attributes(organization_id, definition, context, period)
      {
        organization_id: organization_id,
        usage_meter_definition_id: definition.id,
        starts_at: period.starts_at,
        ends_at: period.ends_at,
        window_policy: definition.window_policy,
        time_zone_name: period.time_zone_name,
        period_reference_digest: period.reference_digest,
        subscription_id: context&.subscription_id,
        plan_version_id: context&.plan_version_id,
        subscription_revision: context&.revision,
        created_at: @clock.call
      }
    end
  end
end
