# frozen_string_literal: true

module Identity
  class InvalidAccountLink < Error
    def initialize(reason_code: "account_link_invalid")
      super(reason_code: reason_code)
    end
  end
end
