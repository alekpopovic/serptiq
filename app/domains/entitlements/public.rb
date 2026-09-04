# frozen_string_literal: true

module Entitlements
  module Public
    module_function

    def validate_catalog(path: Catalog::DEFAULT_PATH, plans_path: Catalog::DEFAULT_PLANS_PATH)
      Catalog.load(path: path, plans_path: plans_path)
    end

    def sync_catalog(path: Catalog::DEFAULT_PATH, plans_path: Catalog::DEFAULT_PLANS_PATH, dry_run: false)
      CatalogSync.new(catalog: validate_catalog(path: path, plans_path: plans_path)).call(dry_run: dry_run)
    end

    def catalog_entries
      CatalogQuery.new.call
    end

    def bind_subscription(**attributes)
      BindSubscriptionContext.new.call(**attributes)
    end

    def resolve(**attributes)
      Resolver.new.call(**attributes)
    end

    def set_organization_override(**attributes)
      SetOrganizationOverride.new.call(**attributes)
    end

    def revoke_organization_override(**attributes)
      RevokeOrganizationOverride.new.call(**attributes)
    end

    def diagnostic_report(**attributes)
      BuildDiagnosticReport.new.call(**attributes)
    end

    def active_subscription_context(organization_id:)
      context = SubscriptionContext.active.find_by(organization_id: organization_id)
      return unless context

      SubscriptionProjection.new(
        subscription_id: context.subscription_id,
        plan_version_id: context.plan_version_id,
        revision: context.subscription_revision
      )
    end

    def resolve_plan_snapshot(**attributes)
      PlanSnapshotResolver.new.call(**attributes)
    end
  end
end
