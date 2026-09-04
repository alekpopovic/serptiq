# frozen_string_literal: true

module Entitlements
  class RevokeOrganizationOverride
    def initialize(clock: -> { Time.current }, authorizer: OverrideAuthorizer.new)
      @clock = clock
      @authorizer = authorizer
    end

    def call(organization_id:, override_id:, actor_membership:, authorization:)
      @authorizer.call(
        actor_membership: actor_membership, organization_id: organization_id, authorization: authorization
      )
      now = @clock.call
      override = OrganizationOverride.transaction do
        record = OrganizationOverride.lock.find_by!(id: override_id, organization_id: organization_id)
        unless record.revoked_at?
          record.update!(revoked_at: now, revoked_by_membership_id: actor_membership.id)
          Auditing::Public.record!(
            organization_id: record.organization_id,
            actor_membership_id: actor_membership.id,
            action: "entitlement.override_revoked",
            target_type: "OrganizationEntitlementOverride",
            target_id: record.id,
            result: "succeeded",
            metadata: {
              operation: "revoke",
              entitlement: record.definition.key,
              source: record.source,
              status: "revoked"
            }
          )
        end
        record
      end
      Current.entitlement_cache&.clear
      override
    rescue ActiveRecord::RecordNotFound
      raise OverrideInvalid.new(reason_code: "entitlement_override_not_found"), cause: nil
    end
  end
end
