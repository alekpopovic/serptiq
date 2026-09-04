# frozen_string_literal: true

module Usage
  class DashboardsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    layout "authenticated"
    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "billing.read", only: :show
    permission_hint "plans.read", only: :show

    def show
      @usage_dashboard = Public.organization_dashboard(
        organization_id: Current.organization.id,
        authorization: authorization_decision!("billing.read")
      )
    end

    private

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_usage_path(Current.organization.slug), status: :moved_permanently
    end
  end
end
