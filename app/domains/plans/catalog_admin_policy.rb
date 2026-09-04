# frozen_string_literal: true

module Plans
  class CatalogAdminPolicy
    PERMISSIONS = CatalogAccessGrant::PERMISSIONS

    def decision(user:, permission:)
      permission = permission.to_s
      user_id = user.id.to_s if user&.respond_to?(:id)
      active_user = user&.respond_to?(:active?) && user.active?
      allowed = active_user && PERMISSIONS.include?(permission) && grant_exists?(user_id, permission)
      CatalogDecision.new(
        allowed: allowed,
        permission_key: permission,
        actor_user_id: user_id,
        reason_code: allowed ? "platform_permission_granted" : "platform_permission_missing"
      )
    end

    def authorize!(**attributes)
      result = decision(**attributes)
      raise CatalogAccessDenied.new(reason_code: result.reason_code) unless result.allow?

      result
    end

    private

    def grant_exists?(user_id, permission)
      permissions = permission == "plan_catalog.read" ?
        %w[plan_catalog.read plan_catalog.publish] : [ permission ]
      CatalogAccessGrant.active.exists?(user_id: user_id, permission: permissions)
    end
  end
end
