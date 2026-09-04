# frozen_string_literal: true

module Tenancy
  class OrganizationSwitchesController < ApplicationController
    include Identity::LoginRequired
    include CurrentOrganization

    DESTINATIONS = {
      "dashboard" => ->(controller) { controller.organization_dashboard_path(Current.organization.slug) },
      "settings" => ->(controller) { controller.organization_settings_path(Current.organization.slug) }
    }.freeze

    before_action :establish_current_organization!
    permission_required "organization.read", only: :show

    def show
      destination = DESTINATIONS.fetch(params[:destination].to_s, DESTINATIONS.fetch("dashboard"))
      redirect_to destination.call(self), status: :found
    end
  end
end
