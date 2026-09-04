# frozen_string_literal: true

module Tenancy
  module Public
    module_function

    # Prompts 024 and 028 replace this pre-schema fallback with membership and
    # invitation-backed decisions. Keeping the boundary explicit lets the UI
    # remain honest without creating tenant records inside Identity.
    def first_run_status(user:)
      raise ArgumentError, "active identity user is required" unless Identity::Public.active_user?(user)

      FirstRunStatus.new(kind: :no_organization)
    end
  end
end
