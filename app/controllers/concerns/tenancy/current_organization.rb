# frozen_string_literal: true

module Tenancy
  module CurrentOrganization
    extend ActiveSupport::Concern

    private

    def establish_current_organization!
      @requested_organization_slug = params[:organization_slug].to_s
      context = Public.resolve_organization_context(
        user: Current.user,
        selector: @requested_organization_slug.presence || params[:organization_id]
      )
      Current.assign_tenant(
        organization: context.organization,
        membership: context.membership
      )
      Shared::Observability::Context.attach_resources(organization_id: context.organization.id)
    end

    def organization_slug_is_canonical?
      @requested_organization_slug == Current.organization&.slug
    end
  end
end
