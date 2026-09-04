# frozen_string_literal: true

module Authorization
  class GrantAuthority
    def initialize(effective_permissions: EffectivePermissionQuery.new)
      @effective_permissions = effective_permissions
    end

    def authorize!(actor:, principal:, grantee_type:, role:, scope:)
      raise AssignmentDenied.new(reason_code: "owner_assignment_forbidden") if role.key == "owner"
      raise AssignmentDenied.new(reason_code: "resource_unavailable") if role.archived_at?
      raise AssignmentDenied.new(reason_code: "scope_mismatch") unless role_available_to?(role, actor.organization_id)
      raise AssignmentDenied.new(reason_code: "scope_mismatch") unless assignable_at?(role, scope.type)
      return true if actor.owner?

      organization_permissions = @effective_permissions.call(
        organization_id: actor.organization_id,
        membership_id: actor.id,
        scope_type: "Organization",
        scope_id: actor.organization_id
      )
      raise AssignmentDenied.new(reason_code: "grant_authority_missing") unless
        organization_permissions.include?("roles.assign")

      candidate_keys = permission_keys_for(role, scope.type)
      actor_keys = @effective_permissions.call(
        organization_id: actor.organization_id,
        membership_id: actor.id,
        scope_type: scope.type,
        scope_id: scope.id,
        all_permission_scopes: scope.type == "Organization"
      ).permission_keys
      missing = candidate_keys - actor_keys
      if missing.any? && affects_actor?(actor, principal, grantee_type)
        raise AssignmentDenied.new(reason_code: "self_escalation")
      end
      raise AssignmentDenied.new(reason_code: "grant_exceeds_authority") if missing.any?

      true
    end

    def authorize_revoke!(actor:, principal:, grantee_type:, role:, scope:)
      return true if actor.owner?

      organization_permissions = @effective_permissions.call(
        organization_id: actor.organization_id,
        membership_id: actor.id,
        scope_type: "Organization",
        scope_id: actor.organization_id
      )
      raise AssignmentDenied.new(reason_code: "grant_authority_missing") unless
        organization_permissions.include?("roles.assign")

      actor_keys = @effective_permissions.call(
        organization_id: actor.organization_id,
        membership_id: actor.id,
        scope_type: scope.type,
        scope_id: scope.id,
        all_permission_scopes: scope.type == "Organization"
      ).permission_keys
      missing = permission_keys_for(role, scope.type) - actor_keys
      raise AssignmentDenied.new(reason_code: "grant_exceeds_authority") if missing.any?

      true
    end

    private

    def role_available_to?(role, organization_id)
      role.system? || role.organization_id.to_s == organization_id.to_s
    end

    def assignable_at?(role, scope_type)
      required_scope = scope_type == "Organization" ? "organization" : "project"
      role.assignable_scopes.include?(required_scope)
    end

    def permission_keys_for(role, scope_type)
      permissions = role.permissions.where(active: true)
      permissions = permissions.where(scope: "project") unless scope_type == "Organization"
      permissions.pluck(:key)
    end

    def affects_actor?(actor, principal, grantee_type)
      grantee_type == "Membership" ? principal.id == actor.id : principal.includes_membership?(actor.id)
    end
  end
end
