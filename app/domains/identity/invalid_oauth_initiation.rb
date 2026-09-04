# frozen_string_literal: true

module Identity
  class InvalidOauthInitiation < Shared::Public::ValidationError
    def initialize(reason_code: "oauth_start_invalid")
      super(reason_code: reason_code)
    end
  end
end
