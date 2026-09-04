# frozen_string_literal: true

module Identity
  class OauthInitiationLimited < Shared::Public::RateLimitError
    def initialize(reason_code: "oauth_start_limited")
      super(reason_code: reason_code)
    end
  end
end
