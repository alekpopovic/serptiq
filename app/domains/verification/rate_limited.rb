# frozen_string_literal: true

module Verification
  class RateLimited < Shared::Public::RateLimitError
    attr_reader :retry_after

    def initialize(retry_after:)
      @retry_after = Integer(retry_after).clamp(1, 86_400)
      super(reason_code: "verification_attempt_rate_limited")
    end
  end
end
