# frozen_string_literal: true

module Billing
  class SupportPolicy
    def decision(user:, permission:)
      permission = permission.to_s
      user_id = user.id.to_s if user&.respond_to?(:id)
      active = user&.respond_to?(:active?) && user.active?
      allowed = active && SupportAccessGrant::PERMISSIONS.include?(permission) &&
        grant_exists?(user_id, permission)
      SupportDecision.new(
        allowed: allowed,
        permission_key: permission,
        actor_user_id: user_id,
        reason_code: allowed ? "billing_support_permission_granted" : "billing_support_permission_missing"
      )
    end

    def authorize!(**attributes)
      result = decision(**attributes)
      raise SupportAccessDenied.new(reason_code: result.reason_code) unless result.allow?

      result
    end

    private

    def grant_exists?(user_id, permission)
      permissions = permission == "billing_support.read" ?
        %w[billing_support.read billing_support.manage] : [ permission ]
      SupportAccessGrant.active.exists?(user_id: user_id, permission: permissions)
    end
  end
end
