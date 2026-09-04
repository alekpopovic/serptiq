# frozen_string_literal: true

module Tenancy
  class OrganizationsController < ApplicationController
    include Identity::LoginRequired

    layout "authenticated"

    authorization_exempt :new, :create, reason: "creates_first_tenant_context"

    def new
      @organization = Organization.new(default_locale: Current.user.locale, time_zone: Current.user.time_zone)
      prepare_form
    end

    def create
      @organization = Organization.new(organization_params)
      result = Public.create_organization(user: Current.user, **organization_params.to_h.symbolize_keys)
      rotate_current_session!
      redirect_to organization_dashboard_path(result.organization.slug),
        notice: "Organization created.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @organization = error.record if error.record.is_a?(Organization)
      prepare_form
      render :new, status: :unprocessable_content
    rescue ActiveRecord::RecordNotUnique
      @organization.errors.add(:slug, "has already been taken")
      prepare_form
      render :new, status: :unprocessable_content
    end

    private

    def organization_params
      params.expect(organization: %i[name slug default_locale time_zone])
    end

    def prepare_form
      @locales = [ [ "English", "en" ] ].freeze
      @time_zones = ActiveSupport::TimeZone.all.map(&:name).freeze
    end
  end
end
