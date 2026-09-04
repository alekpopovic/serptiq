# frozen_string_literal: true

module Plans
  class CatalogVersionBumpInvalid < Shared::Public::ConflictError
    def initialize(reason_code: "plan_version_bump_required")
      super
    end
  end
end
