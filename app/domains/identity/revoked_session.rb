# frozen_string_literal: true

module Identity
  class RevokedSession < Error
    def initialize
      super(reason_code: "session_revoked")
    end
  end
end
