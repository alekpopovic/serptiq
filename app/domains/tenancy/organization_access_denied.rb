# frozen_string_literal: true

module Tenancy
  class OrganizationAccessDenied < Shared::Public::AuthorizationError
    def initialize(reason_code: "organization_access_denied")
      super(reason_code: reason_code)
    end
  end
end
