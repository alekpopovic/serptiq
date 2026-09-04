# frozen_string_literal: true

module Entitlements
  class AccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "entitlement_access_denied")
      super
    end
  end
end
