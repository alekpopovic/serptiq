# frozen_string_literal: true

module Plans
  class CatalogTargetUnavailable < Shared::Public::ConflictError
    def initialize(reason_code: "plan_catalog_target_unavailable")
      super
    end
  end
end
