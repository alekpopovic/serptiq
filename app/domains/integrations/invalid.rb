# frozen_string_literal: true

module Integrations
  class Invalid < Shared::Public::ValidationError
    def initialize(reason_code: "integration_invalid")
      super(reason_code: reason_code)
    end
  end
end
