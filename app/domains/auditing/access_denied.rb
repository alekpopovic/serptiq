# frozen_string_literal: true

module Auditing
  class AccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "audit_access_denied")
      super
    end
  end
end
