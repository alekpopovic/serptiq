# frozen_string_literal: true

module Verification
  class AccessDenied < Shared::Public::AuthorizationError
    def initialize
      super(reason_code: "verification_access_denied")
    end
  end
end
