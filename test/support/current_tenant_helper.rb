# frozen_string_literal: true

module TestSupport
  module CurrentTenantHelper
    def with_current_tenant(user:, organization:, membership:, current_class: Object.const_get(:Current))
      current_class.set(user: user, organization: organization, membership: membership) { yield }
    ensure
      current_class&.reset
    end
  end
end
