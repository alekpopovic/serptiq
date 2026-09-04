# frozen_string_literal: true

module Identity
  class LastSignInIdentity < Shared::Public::ConflictError
    def initialize
      super(reason_code: "last_sign_in_identity")
    end
  end
end
