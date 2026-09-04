# frozen_string_literal: true

module Authorization
  class AssignmentInvalid < Shared::Public::ValidationError
    def initialize(reason_code: "role_assignment_invalid")
      super(reason_code: reason_code)
    end
  end
end
