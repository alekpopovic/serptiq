# frozen_string_literal: true

module Identity
  class RecentAuthenticationRequired < Error
    def initialize
      super(reason_code: "recent_authentication_required")
    end
  end
end
