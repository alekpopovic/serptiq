# frozen_string_literal: true

module Identity
  class ExpiredSession < Error
    def initialize(reason_code: "session_expired")
      super(reason_code: reason_code)
    end
  end
end
