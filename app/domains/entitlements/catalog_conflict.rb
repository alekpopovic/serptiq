# frozen_string_literal: true

module Entitlements
  class CatalogConflict < Shared::Public::ConflictError
    def initialize(reason_code: "entitlement_catalog_conflict")
      super
    end
  end
end
