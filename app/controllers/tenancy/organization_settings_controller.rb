# frozen_string_literal: true

module Tenancy
  class OrganizationSettingsController < ApplicationController
    include Identity::LoginRequired
    include CurrentOrganization

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "organization.read", only: :show
    permission_required "organization.update", only: :update
    permission_hint "organization.update", only: :show
    permission_hint "organization.transfer", only: :show
    permission_hint "audit_log.read", only: :show

    def show
      @organization = Current.organization
      prepare_form
    end

    def update
      @organization = Public.update_organization(
        actor_membership: Current.membership,
        authorization: authorization_decision!("organization.update"),
        **organization_params.to_h.symbolize_keys
      )
      redirect_to organization_settings_path(@organization.slug),
        notice: "Organization settings were updated.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @organization = if error.record.is_a?(Organization)
        error.record
      else
        Current.organization.tap { |organization| organization.errors.add(:slug, "could not be changed") }
      end
      prepare_form
      render :show, status: :unprocessable_content
    end

    private

    def organization_params
      params.expect(organization: %i[name slug default_locale time_zone])
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_settings_path(Current.organization.slug), status: :moved_permanently
    end

    def prepare_form
      @locales = [ [ "English", "en" ] ].freeze
      @time_zones = ActiveSupport::TimeZone.all.map(&:name).freeze
    end
  end
end
