# frozen_string_literal: true

module Tenancy
  OrganizationContext = Data.define(:organization, :membership) do
    def initialize(organization:, membership:)
      valid = organization.is_a?(Organization) && membership.is_a?(Membership) &&
        organization.persisted? && membership.persisted? &&
        membership.organization_id == organization.id && organization.active? && membership.active?
      raise ArgumentError, "verified active organization context is required" unless valid

      super(organization: organization, membership: membership)
      freeze
    end
  end
end
