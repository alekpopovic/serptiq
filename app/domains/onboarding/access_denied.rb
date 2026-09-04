# frozen_string_literal: true

module Onboarding
  class AccessDenied < Shared::Public::AuthorizationError
    def initialize
      super(reason_code: "onboarding_access_denied")
    end
  end
end
