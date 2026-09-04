# frozen_string_literal: true

module Usage
  class QuotaExceeded < Shared::Public::QuotaError
    attr_reader :denial

    def initialize(denial:, reason_code: "usage_quota_exceeded")
      @denial = denial
      super(reason_code: reason_code)
    end
  end
end
