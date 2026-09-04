# frozen_string_literal: true

module Billing
  class AuthorizeManagement
    PERMISSION = "billing.manage"

    def call(actor_membership:, organization:, authorization:)
      actor = actor_membership.reload
      tenant = organization.reload
      valid = actor.active? && tenant.active? && actor.organization_id == tenant.id &&
        authorization.respond_to?(:allow?) && authorization.allow? &&
        authorization.respond_to?(:permission_key) && authorization.permission_key == PERMISSION &&
        authorization.respond_to?(:actor_membership_id) && authorization.actor_membership_id.to_s == actor.id.to_s &&
        authorization.respond_to?(:organization_id) && authorization.organization_id.to_s == tenant.id.to_s &&
        authorization.respond_to?(:scope_type) && authorization.scope_type == "Organization" &&
        authorization.respond_to?(:scope_id) && authorization.scope_id.to_s == tenant.id.to_s
      raise AccessDenied unless valid

      tenant
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied, cause: nil
    end
  end
end
