# frozen_string_literal: true

module Verification
  class IntegrationPermission
    def call(actor_membership:, organization_id:)
      Authorization::Public.authorize_access!(
        actor_membership: actor_membership,
        permission_key: "integrations.manage",
        organization: organization_id
      )
    rescue Shared::Public::AuthorizationError
      raise AccessDenied, cause: nil
    end
  end
end
