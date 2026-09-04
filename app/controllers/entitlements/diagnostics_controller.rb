# frozen_string_literal: true

module Entitlements
  class DiagnosticsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    layout "authenticated"
    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "plans.read", only: :show

    def show
      @diagnostic_report = Public.diagnostic_report(
        organization_id: Current.organization.id,
        authorization: authorization_decision!("plans.read")
      )
    end

    private

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_entitlements_path(Current.organization.slug), status: :moved_permanently
    end
  end
end
