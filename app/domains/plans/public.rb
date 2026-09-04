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

    def authorize_catalog!(user:, permission:)
      CatalogAdminPolicy.new.authorize!(user: user, permission: permission)
    end

    def catalog_decision(user:, permission:)
      CatalogAdminPolicy.new.decision(user: user, permission: permission)
    end

    def catalog_entries
      CatalogQuery.new.call
    end

    def version_snapshot(id:)
      VersionLookup.new.call(id: id)
    end

    def publish_version(**attributes)
      PublishPlanVersion.new.call(**attributes)
    end

    def retire_version(**attributes)
      RetirePlanVersion.new.call(**attributes)
    end
  end
end
