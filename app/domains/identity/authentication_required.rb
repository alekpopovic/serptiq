# frozen_string_literal: true

module Identity
  class AuthenticationRequired < Error
    def initialize
      super(reason_code: "not_authenticated")
    end
  end
end
