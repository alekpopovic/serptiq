# frozen_string_literal: true

module Identity
  class InactiveUser < Error
    def initialize
      super(reason_code: "user_inactive")
    end
  end
end
