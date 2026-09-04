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
  end
end
