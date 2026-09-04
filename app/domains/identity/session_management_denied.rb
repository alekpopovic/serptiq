# frozen_string_literal: true

module Identity
  class SessionManagementDenied < Error
    def initialize(reason_code: "session_management_invalid")
      super(reason_code: reason_code)
    end
  end
end
