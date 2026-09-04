# frozen_string_literal: true

module Authorization
  class Decision
    OWNER_ONLY_PERMISSIONS = %w[organization.transfer organization.delete].freeze
    ARCHIVED_PROJECT_PERMISSIONS = %w[projects.read projects.archive projects.delete].freeze

    def self.call(request = nil, validate_resource: true, **attributes)
      request ||= AccessRequest.new(**attributes)
      new.call(request, validate_resource: validate_resource)
    end

    def initialize(effective_permissions: EffectivePermissionQuery.new,
      scope_registry: ScopeRegistry.new, instrumentation: DecisionInstrumentation.new)
      @effective_permissions = effective_permissions
      @scope_registry = scope_registry
      @instrumentation = instrumentation
    end

    def call(request, validate_resource: true)
      permission = nil
      result = evaluate(request, validate_resource: validate_resource) { |resolved| permission = resolved }
      @instrumentation.with_actor(request.actor_membership_id).emit(result, permission: permission)
      result
    end

    private

    def evaluate(request, validate_resource:)
      return denied(request, "not_authenticated") unless request.authenticated?
      return denied(request, "scope_mismatch") unless
        request.actor_organization_id.to_s == request.organization_id

      organization = Tenancy::Public.authorization_organization(organization_id: request.organization_id)
      return denied(request, "scope_mismatch") unless organization
      return denied(request, "resource_unavailable") unless organization.active?

      membership = Tenancy::Public.authorization_membership(
        organization_id: request.organization_id,
        membership_id: request.actor_membership_id
      )
      return denied(request, "membership_inactive") unless membership&.active?

      permission = Permission.find_by(key: request.permission_key, active: true)
      return denied(request, "unknown_permission") unless permission

      yield permission
      chain = @scope_registry.resolve_chain(
        organization_id: request.organization_id,
        scope_type: request.scope_type,
        scope_id: request.scope_id
      )
      return denied(request, "scope_mismatch") if chain.empty?
      return denied(request, "scope_mismatch") unless requested_project_matches?(request, chain)
      archived_project = archived_project_access?(permission, chain)
      return denied(request, "resource_unavailable") unless chain.all?(&:active?) || archived_project
      return denied(request, "scope_mismatch") unless permission_matches_scope?(permission, request)
      if validate_resource
        return denied(request, "scope_mismatch") unless resource_matches_scope?(request)
        return denied(request, "resource_unavailable") if request.resource && !request.resource.available?
      end
      if OWNER_ONLY_PERMISSIONS.include?(permission.key) && !membership.owner?
        return denied(request, "owner_permission_required")
      end

      effective = effective_permissions(request, archived_project: archived_project)
      unless effective.include?(permission.key)
        return denied(request, archived_project ? "resource_unavailable" : "permission_missing")
      end

      sources = effective.owner? ? [ "organization_ownership" ] : effective.sources_for(permission.key)
      DecisionResult.new(
        allowed: true,
        reason_code: "permission_granted",
        permission_key: request.permission_key,
        actor_membership_id: request.actor_membership_id,
        organization_id: request.organization_id,
        scope_type: request.scope_type,
        scope_id: request.scope_id,
        sources: sources
      )
    end

    def denied(request, reason_code)
      DecisionResult.new(
        allowed: false,
        reason_code: reason_code,
        permission_key: request.permission_key,
        actor_membership_id: request.actor_membership_id,
        organization_id: request.organization_id,
        scope_type: request.scope_type,
        scope_id: request.scope_id
      )
    end

    def permission_matches_scope?(permission, request)
      expected = request.scope_type == "Organization" ? "organization" : "project"
      permission.scope == expected
    end

    def requested_project_matches?(request, chain)
      return true unless request.property_id && request.project_id

      project = chain.find { |scope| scope.type == "Project" }
      project&.id == request.project_id
    end

    def resource_matches_scope?(request)
      resource = request.resource
      return true unless resource

      resource.organization_id == request.organization_id &&
        resource.scope_type == request.scope_type && resource.scope_id == request.scope_id
    end

    def archived_project_access?(permission, chain)
      organization, project = chain
      chain.length == 2 && organization&.active? && project&.type == "Project" && project.archived? &&
        ARCHIVED_PROJECT_PERMISSIONS.include?(permission.key)
    end

    def effective_permissions(request, archived_project:)
      if archived_project
        @effective_permissions.call(
          organization_id: request.organization_id,
          membership_id: request.actor_membership_id,
          scope_type: "Organization",
          scope_id: request.organization_id,
          all_permission_scopes: true
        )
      else
        @effective_permissions.call(
          organization_id: request.organization_id,
          membership_id: request.actor_membership_id,
          scope_type: request.scope_type,
          scope_id: request.scope_id
        )
      end
    end
  end
end
