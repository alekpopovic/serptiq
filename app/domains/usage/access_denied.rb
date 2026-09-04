# frozen_string_literal: true

module Usage
  class AccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "usage_adjustment_denied")
      super
    end
  end
end
