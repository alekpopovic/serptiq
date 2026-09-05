# frozen_string_literal: true

module Crawling
  class AccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "crawl_policy_scope_unavailable")
      super(reason_code: reason_code)
    end
  end
end
