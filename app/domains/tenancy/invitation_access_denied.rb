# frozen_string_literal: true

module Tenancy
  class InvitationAccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "invitation_unavailable")
      super(reason_code: reason_code)
    end
  end
end
