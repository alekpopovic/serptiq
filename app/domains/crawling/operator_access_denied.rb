# frozen_string_literal: true

module Crawling
  class OperatorAccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "crawler_control_permission_missing")
      super("crawler control permission is required", reason_code: reason_code)
    end
  end
end
