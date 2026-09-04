# frozen_string_literal: true

module Authorization
  class AuthenticationRequired < Shared::Public::AuthenticationError
    attr_reader :access_decision

    def initialize(access_decision:)
      @access_decision = access_decision
      super(reason_code: access_decision.reason_code)
    end
  end
end
