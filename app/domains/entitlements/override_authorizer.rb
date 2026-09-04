# frozen_string_literal: true

module Entitlements
  class OverrideAuthorizer
    def call(actor_membership:, organization_id:, authorization:)
      allowed = actor_membership&.respond_to?(:active?) && actor_membership.active? &&
        actor_membership.organization_id.to_s == organization_id.to_s &&
        Shared::Public.application_uuid?(actor_membership.id) &&
        actor_membership.respond_to?(:user_id) &&
        authorization&.respond_to?(:allow?) && authorization.allow? &&
        authorization.respond_to?(:permission_key) && authorization.respond_to?(:actor_user_id) &&
        authorization.permission_key == "plan_catalog.publish" &&
        authorization.actor_user_id.to_s == actor_membership.user_id.to_s
      raise AccessDenied.new(reason_code: "entitlement_override_platform_authority_required") unless allowed

      true
    end
  end
end
