# frozen_string_literal: true

module Usage
  class Invalid < Shared::Public::ValidationError
    def initialize(reason_code: "usage_invalid")
      super
    end
  end
end
