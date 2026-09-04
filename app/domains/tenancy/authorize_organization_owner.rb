# frozen_string_literal: true

module Tenancy
  class AuthorizeOrganizationOwner
    def call(membership:)
      raise OrganizationAccessDenied unless membership.is_a?(Membership) && membership.active?

      state = OwnerInvariant.new.lock!(organization_id: membership.organization_id)
      OwnerInvariant.new.require_current_owner!(state: state, actor_membership_id: membership.id)
      organization = state.organization
      raise OrganizationAccessDenied unless organization.active?

      organization
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end
  end
end
