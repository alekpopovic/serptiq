# frozen_string_literal: true

module Authorization
  class AccessDenied < Shared::Public::AuthorizationError
    attr_reader :decision

    def initialize(decision:)
      @decision = decision
      super(reason_code: decision.reason_code)
    end
  end
end
