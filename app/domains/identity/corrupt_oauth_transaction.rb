# frozen_string_literal: true

module Identity
  class CorruptOauthTransaction < Error
    def initialize
      super(reason_code: "oauth_transaction_corrupt")
    end
  end
end
