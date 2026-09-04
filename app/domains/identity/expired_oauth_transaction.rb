# frozen_string_literal: true

module Identity
  class ExpiredOauthTransaction < Error
    def initialize
      super(reason_code: "oauth_transaction_expired")
    end
  end
end
