# frozen_string_literal: true

module Usage
  class UsageDashboardAuthorizer
    def call(organization_id:, authorization:)
      allowed = authorization&.respond_to?(:allow?) && authorization.allow? &&
        authorization.respond_to?(:permission_key) && authorization.permission_key == "billing.read" &&
        authorization.respond_to?(:organization_id) && authorization.organization_id.to_s == organization_id.to_s &&
        authorization.respond_to?(:scope_type) && authorization.scope_type == "Organization" &&
        authorization.respond_to?(:scope_id) && authorization.scope_id.to_s == organization_id.to_s &&
        authorization.respond_to?(:actor_membership_id) &&
        Shared::Public.application_uuid?(authorization.actor_membership_id)
      raise AccessDenied.new(reason_code: "usage_dashboard_forbidden") unless allowed

      true
    end
  end
end
