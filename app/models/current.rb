# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :session, :organization, :membership, :entitlement_cache

  def assign_tenant(organization:, membership:)
    valid = user && organization && membership &&
      membership.user_id == user.id && membership.organization_id == organization.id &&
      membership.active? && organization.active?
    raise ArgumentError, "verified current tenant context is required" unless valid

    self.organization = organization
    self.membership = membership
  end
end
