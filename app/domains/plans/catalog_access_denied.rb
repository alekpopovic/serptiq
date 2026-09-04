# frozen_string_literal: true

module Plans
  class CatalogAccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "plan_catalog_access_denied")
      super
    end
  end
end
