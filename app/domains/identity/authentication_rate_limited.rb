# frozen_string_literal: true

module Identity
  class AuthenticationRateLimited < Shared::Public::RateLimitError
    attr_reader :scope, :retry_after

    def initialize(scope:, retry_after:)
      @scope = scope.to_s
      @retry_after = Integer(retry_after).clamp(1, 86_400)
      unless AuthenticationRateLimitPolicy::SCOPES.include?(@scope)
        raise ArgumentError, "unsupported authentication rate-limit scope"
      end

      super(reason_code: "#{@scope}_rate_limited")
    end
  end
end
