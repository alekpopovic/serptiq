# frozen_string_literal: true

module Properties
  class PropertyTransitionInvalid < Shared::Public::ConflictError
    def initialize(reason_code: "property_transition_invalid")
      super(reason_code: reason_code)
    end
  end
end
