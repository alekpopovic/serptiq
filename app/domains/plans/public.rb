# frozen_string_literal: true

module Plans
  module Public
    module_function

    def validate_catalog(path: Catalog::DEFAULT_PATH)
      Catalog.load(path: path)
    end

    def sync_catalog(path: Catalog::DEFAULT_PATH, dry_run: false)
      CatalogSync.new(catalog: validate_catalog(path: path)).call(dry_run: dry_run)
    end

    def compare_catalog(path: Catalog::DEFAULT_PATH)
      CatalogComparison.new(catalog: validate_catalog(path: path)).call
    end

    def authorize_catalog!(user:, permission:)
      CatalogAdminPolicy.new.authorize!(user: user, permission: permission)
    end

    def catalog_decision(user:, permission:)
      CatalogAdminPolicy.new.decision(user: user, permission: permission)
    end

    def catalog_entries
      CatalogQuery.new.call
    end

    def current_offers(**attributes)
      OfferCatalogQuery.new.call(**attributes)
    end

    def version_snapshot(id:, lock: false)
      VersionLookup.new.call(id: id, lock: lock)
    end

    def catalog_version(plan_key:, version:, lock: false)
      CatalogVersionLookup.new.call(plan_key: plan_key, version: version, lock: lock)
    end

    def purchasable_version(**attributes)
      CurrentVersionSelector.new.call(**attributes)
    end

    def plan_change_target(**attributes)
      ChangeTargetSelector.new.call(**attributes)
    end

    def register_snapshot_reference(**attributes)
      RegisterSnapshotReference.new.call(**attributes)
    end

    def publish_version(path: Catalog::DEFAULT_PATH, **attributes)
      PublishPlanVersion.new(catalog: validate_catalog(path: path)).call(**attributes)
    end

    def retire_version(**attributes)
      RetirePlanVersion.new.call(**attributes)
    end
  end
end
