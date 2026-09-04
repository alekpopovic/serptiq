# frozen_string_literal: true

module Identity
  class ConsumedOauthTransaction < Error
    def initialize
      super(reason_code: "oauth_transaction_consumed")
    end
  end
end
