# frozen_string_literal: true

module Tenancy
  class AuthorizeMembershipAccess
    def call(membership:, permission_key:, authorization: nil)
      return AuthorizeOrganizationOwner.new.call(membership: membership) unless authorization

      actor = Membership.find(membership&.id)
      organization = Organization.find(actor.organization_id)
      allowed = authorization.respond_to?(:allow?) && authorization.allow?
      matching = authorization.respond_to?(:permission_key) &&
        authorization.permission_key == permission_key.to_s &&
        authorization.respond_to?(:actor_membership_id) &&
        authorization.actor_membership_id.to_s == actor.id.to_s &&
        authorization.organization_id.to_s == organization.id.to_s &&
        authorization.scope_type == "Organization" &&
        authorization.scope_id.to_s == organization.id.to_s
      raise OrganizationAccessDenied unless actor.active? && organization.active? && allowed && matching

      organization
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end
  end
end
