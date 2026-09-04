# frozen_string_literal: true

module Tenancy
  class AuthorizeOrganizationOwner
    def call(membership:)
      raise OrganizationAccessDenied unless membership.is_a?(Membership) && membership.active?

      organization = Organization.find(membership.organization_id)
      owned = organization.active? && OrganizationOwnership.where(
        organization_id: organization.id,
        membership_id: membership.id,
        ended_at: nil
      ).exists?
      raise OrganizationAccessDenied unless owned

      organization
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end
  end
end
