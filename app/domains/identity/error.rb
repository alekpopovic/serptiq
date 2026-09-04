# frozen_string_literal: true

module Identity
  class Error < Shared::Public::AuthenticationError
    def initialize(message = nil, reason_code:)
      super(message, reason_code: reason_code)
    end
  end
end
