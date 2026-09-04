# frozen_string_literal: true

module Authorization
  class AssignmentDenied < Shared::Public::AuthorizationError
    def initialize(reason_code:)
      super(reason_code: reason_code)
    end
  end
end
