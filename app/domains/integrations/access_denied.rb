# frozen_string_literal: true

module Integrations
  class AccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "integration_access_denied")
      super(reason_code: reason_code)
    end
  end
end
