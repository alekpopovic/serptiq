# frozen_string_literal: true

module Identity
  class InvalidSession < Error
    def initialize
      super(reason_code: "session_invalid")
    end
  end
end
