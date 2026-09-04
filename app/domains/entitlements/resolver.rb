# frozen_string_literal: true

module Entitlements
  class Resolver
    def initialize(typed_value: TypedValue.new)
      @typed_value = typed_value
    end

    def call(organization_id:, entitlement_key:, at: Time.current)
      organization = organization_id.to_s
      raw_key = entitlement_key.to_s
      key = raw_key.byteslice(0, 96)
      return unknown_resolution(key) unless Shared::Public.application_uuid?(organization)
      return cached_unknown(organization, key) unless raw_key.bytesize <= 96 && Definition::KEY_PATTERN.match?(key)
      raise ArgumentError, "entitlement resolution time is invalid" unless
        at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)

      definition = Definition.find_by(key: key)
      return cached_unknown(organization, key) unless definition

      context = SubscriptionContext.active.find_by(organization_id: organization)
      override = current_override(organization, definition.id, at)
      plan_value = context && PlanValue.find_by(
        plan_version_id: context.plan_version_id,
        entitlement_definition_id: definition.id
      )
      cache_key = resolution_cache_key(organization, definition, context, plan_value, override, at)
      cache = Current.entitlement_cache ||= {}
      cache[cache_key] ||= resolve_sources(definition, context, plan_value, override)
    end

    private

    def current_override(organization_id, definition_id, at)
      OrganizationOverride.applicable_at(at).find_by(
        organization_id: organization_id,
        entitlement_definition_id: definition_id
      )
    end

    def resolve_sources(definition, context, plan_value, override)
      if override
        configured_resolution(
          definition, override.value, provenance: "organization_override",
          override: override, plan_version_id: context&.plan_version_id
        )
      elsif context && plan_value.nil?
        misconfigured_resolution(definition, context.plan_version_id)
      elsif plan_value
        normalized_resolution(
          definition,
          @typed_value.deserialize(
            definition: definition, state: plan_value.value_state, stored_value: plan_value.value
          ),
          provenance: "subscribed_plan_version",
          plan_version_id: context.plan_version_id
        )
      else
        configured_resolution(definition, definition.system_default, provenance: "system_default")
      end
    rescue OverrideInvalid
      misconfigured_resolution(definition, context&.plan_version_id)
    end

    def configured_resolution(definition, stored_value, provenance:, override: nil, plan_version_id: nil)
      normalized = @typed_value.deserialize(
        definition: definition, state: "configured", stored_value: stored_value
      )
      normalized_resolution(
        definition, normalized, provenance: provenance, override: override,
        plan_version_id: plan_version_id
      )
    end

    def normalized_resolution(definition, normalized, provenance:, override: nil, plan_version_id: nil)
      state = if normalized.state == "custom"
        "custom_required"
      elsif @typed_value.enabled?(definition: definition, value: normalized.value)
        "enabled"
      else
        "disabled"
      end
      Resolution.new(
        key: definition.key,
        value: normalized.value,
        value_type: definition.value_type,
        unit: definition.unit,
        category: definition.category,
        state: state,
        provenance: provenance,
        reason_code: "entitlement_#{state}",
        definition_checksum: definition.catalog_checksum,
        plan_version_id: plan_version_id,
        override_id: override&.id,
        override_source: override&.source,
        override_expires_at: override&.ends_at
      )
    end

    def misconfigured_resolution(definition, plan_version_id)
      instrument_failure("entitlement_value_missing")
      Resolution.new(
        key: definition.key, value: nil, value_type: definition.value_type,
        unit: definition.unit, category: definition.category, state: "misconfigured",
        provenance: "none", reason_code: "entitlement_value_missing",
        definition_checksum: definition.catalog_checksum, plan_version_id: plan_version_id,
        override_id: nil, override_source: nil, override_expires_at: nil
      )
    end

    def cached_unknown(organization_id, key)
      cache = Current.entitlement_cache ||= {}
      cache[[ organization_id, key, "unknown" ]] ||= unknown_resolution(key)
    end

    def unknown_resolution(key)
      instrument_failure("entitlement_unknown")
      Resolution.new(
        key: key, value: nil, value_type: nil, unit: nil, category: nil,
        state: "unknown", provenance: "none", reason_code: "entitlement_unknown",
        definition_checksum: nil, plan_version_id: nil, override_id: nil,
        override_source: nil, override_expires_at: nil
      )
    end

    def resolution_cache_key(organization_id, definition, context, plan_value, override, at)
      [
        organization_id, definition.key, definition.catalog_checksum,
        context&.subscription_id, context&.subscription_revision, context&.updated_at&.to_f,
        plan_value&.catalog_checksum, plan_value&.updated_at&.to_f,
        override&.id, override&.updated_at&.to_f, at.to_i
      ].freeze
    end

    def instrument_failure(reason_code)
      Shared::Public.emit_structured_event(
        "entitlement.resolution_failed",
        severity: :warn,
        outcome: "failed",
        operation: "resolve",
        reason_code: reason_code
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "entitlement.resolution_failed")
    end
  end
end
