# frozen_string_literal: true

module Identity
  class AccountLinkRequired < Shared::Public::ConflictError
    def initialize
      super(reason_code: "explicit_account_link_required")
    end
  end
end
