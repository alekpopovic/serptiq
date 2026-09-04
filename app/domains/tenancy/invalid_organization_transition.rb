# frozen_string_literal: true

module Tenancy
  class InvalidOrganizationTransition < Shared::Public::ConflictError
    def initialize(reason_code: "organization_transition_invalid")
      super(reason_code: reason_code)
    end
  end
end
