# frozen_string_literal: true

module Tenancy
  class OrganizationsForUser
    def call(user:)
      return [].freeze unless Identity::Public.active_user?(user)

      Organization.joins(:memberships)
        .where(status: "active", deleted_at: nil)
        .where(memberships: { user_id: user.id, status: "active" })
        .order(:name, :id)
        .distinct
        .map do |organization|
          OrganizationSummary.new(
            id: organization.id,
            name: organization.name,
            slug: organization.slug
          )
        end
        .freeze
    end
  end
end
