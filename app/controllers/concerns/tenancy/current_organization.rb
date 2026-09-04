# frozen_string_literal: true

module Tenancy
  module CurrentOrganization
    extend ActiveSupport::Concern

    private

    def establish_current_organization!
      context = Public.resolve_organization_context(
        user: Current.user,
        selector: params[:organization_slug] || params[:organization_id]
      )
      Current.assign_tenant(
        organization: context.organization,
        membership: context.membership
      )
      Shared::Observability::Context.attach_resources(organization_id: context.organization.id)
    end
  end
end
