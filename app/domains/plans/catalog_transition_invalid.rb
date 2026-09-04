# frozen_string_literal: true

module Plans
  class CatalogTransitionInvalid < Shared::Public::ConflictError
    def initialize(reason_code: "plan_catalog_transition_invalid")
      super
    end
  end
end
