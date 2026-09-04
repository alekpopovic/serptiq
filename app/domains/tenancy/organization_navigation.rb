# frozen_string_literal: true

module Tenancy
  class OrganizationNavigation
    def call(user:)
      return [].freeze unless Identity::Public.active_user?(user)

      Organization.joins(:memberships)
        .where.not(status: "deleted")
        .where(memberships: { user_id: user.id, status: "active" })
        .order(:name, :id)
        .distinct
        .map do |organization|
          OrganizationNavigationEntry.new(
            id: organization.id,
            name: organization.name,
            slug: organization.slug,
            status: organization.status
          )
        end
        .freeze
    end
  end
end
