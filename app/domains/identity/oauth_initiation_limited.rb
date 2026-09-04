# frozen_string_literal: true

module Identity
  class OauthInitiationLimited < Shared::Public::RateLimitError
    attr_reader :retry_after

    def initialize(reason_code: "oauth_start_limited", retry_after: 60)
      @retry_after = retry_after
      super(reason_code: reason_code)
    end
  end
end
