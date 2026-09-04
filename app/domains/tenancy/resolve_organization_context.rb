# frozen_string_literal: true

module Tenancy
  class ResolveOrganizationContext
    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    def call(user:, selector:)
      raise OrganizationAccessDenied unless Identity::Public.active_user?(user)

      organization = find_organization(selector)
      membership = Membership.find_by(
        organization_id: organization.id,
        user_id: user.id,
        status: "active"
      )
      raise OrganizationAccessDenied unless organization.active? && membership

      OrganizationContext.new(organization: organization, membership: membership)
    rescue ActiveRecord::RecordNotFound, ArgumentError
      raise OrganizationAccessDenied, cause: nil
    end

    private

    def find_organization(selector)
      value = selector.to_s
      raise OrganizationAccessDenied unless value.bytesize.between?(3, 63)

      relation = Organization.where(deleted_at: nil)
      if UUID_PATTERN.match?(value)
        relation.find(value)
      else
        slug = OrganizationSlug.call(value)
        relation.find_by(slug: slug) || OrganizationSlugAlias.includes(:organization).find_by!(slug: slug).organization
      end
    end
  end
end
