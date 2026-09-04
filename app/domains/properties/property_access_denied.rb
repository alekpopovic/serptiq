# frozen_string_literal: true

module Properties
  class PropertyAccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "scope_mismatch")
      super(reason_code: reason_code)
    end
  end
end
