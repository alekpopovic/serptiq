# frozen_string_literal: true

module Entitlements
  class SetOrganizationOverride
    def initialize(clock: -> { Time.current }, authorizer: OverrideAuthorizer.new)
      @clock = clock
      @authorizer = authorizer
    end

    def call(organization_id:, entitlement_key:, value:, reason:, source:, actor_membership:,
      authorization:, starts_at: nil, ends_at: nil)
      @authorizer.call(
        actor_membership: actor_membership, organization_id: organization_id, authorization: authorization
      )
      definition = Definition.find_by!(key: entitlement_key.to_s)
      normalized = TypedValue.new.normalize(definition: definition, raw: value, custom_allowed: false)
      now = @clock.call
      starts = normalize_time(starts_at) || now
      ends = normalize_time(ends_at)
      attributes = override_attributes(
        organization_id: organization_id, definition: definition, normalized: normalized,
        reason: reason, source: source, actor_membership: actor_membership, starts: starts, ends: ends
      )

      override = OrganizationOverride.transaction do
        existing = OrganizationOverride.where(
          organization_id: organization_id,
          entitlement_definition_id: definition.id,
          revoked_at: nil
        ).lock.first
        existing&.update!(revoked_at: now, revoked_by_membership_id: actor_membership.id)
        record = OrganizationOverride.create!(attributes)
        audit(record, actor_membership, "entitlement.override_set", "set")
        record
      end
      Current.entitlement_cache&.clear
      override
    rescue ActiveRecord::RecordNotFound
      raise OverrideInvalid.new(reason_code: "entitlement_unknown"), cause: nil
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      raise OverrideInvalid.new, cause: error
    end

    private

    def normalize_time(value)
      return if value.nil?
      return value.in_time_zone if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      raise OverrideInvalid.new(reason_code: "entitlement_override_time_invalid")
    end

    def override_attributes(organization_id:, definition:, normalized:, reason:, source:, actor_membership:,
      starts:, ends:)
      {
        organization_id: organization_id,
        entitlement_definition_id: definition.id,
        value_type: definition.value_type,
        value: normalized.stored_value,
        starts_at: starts,
        ends_at: ends,
        reason: reason.to_s.strip,
        source: source.to_s,
        created_by_membership_id: actor_membership.id
      }
    end

    def audit(record, actor, action, operation)
      Auditing::Public.record!(
        organization_id: record.organization_id,
        actor_membership_id: actor.id,
        action: action,
        target_type: "OrganizationEntitlementOverride",
        target_id: record.id,
        result: "succeeded",
        metadata: {
          operation: operation,
          entitlement: record.definition.key,
          source: record.source,
          status: "active"
        }
      )
    end
  end
end
