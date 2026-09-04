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
  end
end
