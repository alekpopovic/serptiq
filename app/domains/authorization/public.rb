# frozen_string_literal: true

module Authorization
  module Public
    module_function

    def validate_catalog(path: Catalog::DEFAULT_PATH)
      Catalog.load(path: path)
    end

    def sync_catalog(path: Catalog::DEFAULT_PATH)
      CatalogSync.new(catalog: validate_catalog(path: path)).call
    end

    def catalog_report(path: Catalog::DEFAULT_PATH)
      CatalogReport.new(catalog: validate_catalog(path: path)).call
    end

    def register_scope(**attributes)
      ScopeRegistry.new.register(**attributes)
    end

    def effective_permissions(**attributes)
      EffectivePermissionQuery.new.call(**attributes)
    end

    def visible_project_scopes(**attributes)
      VisibleProjectScopes.new.call(**attributes)
    end

    def visible_property_scopes(**attributes)
      VisiblePropertyScopes.new.call(**attributes)
    end

    def assign_role(**attributes)
      AssignRole.new.call(**attributes)
    end

    def revoke_role(**attributes)
      RevokeRole.new.call(**attributes)
    end

    def accept_invitation(**attributes)
      AcceptInvitation.new.call(**attributes)
    end

    def decision(request = nil, **attributes)
      Decision.call(request, **attributes)
    end

    def policy(actor_membership:, organization:)
      PolicyAdapter.new(actor_membership: actor_membership, organization: organization)
    end

    def authorize_job!(**attributes, &block)
      JobAuthorizer.new.call(**attributes, &block)
    end

    def access_decision(request = nil, **attributes)
      request ||= AccessRequest.new(**attributes)
      AccessBoundary.new.call(request)
    end

    def authorize_access!(request = nil, **attributes)
      request ||= AccessRequest.new(**attributes)
      AccessBoundary.new.authorize!(request)
    end

    def with_access(request = nil, **attributes, &block)
      request ||= AccessRequest.new(**attributes)
      AccessBoundary.new.with_access(request, &block)
    end

    def authorize_job_access!(**attributes, &block)
      JobAuthorizer.new.access(**attributes, &block)
    end

    def api_error(error, request_id:)
      ApiErrorContract.call(error, request_id: request_id)
    end
  end
end
