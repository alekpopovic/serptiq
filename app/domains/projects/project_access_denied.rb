# frozen_string_literal: true

module Projects
  class ProjectAccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "scope_mismatch")
      super(reason_code: reason_code)
    end
  end
end
