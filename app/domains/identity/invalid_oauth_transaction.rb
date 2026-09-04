# frozen_string_literal: true

module Identity
  class InvalidOauthTransaction < Error
    def initialize
      super(reason_code: "oauth_transaction_invalid")
    end
  end
end
