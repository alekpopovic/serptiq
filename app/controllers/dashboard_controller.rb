# frozen_string_literal: true

class DashboardController < ApplicationController
  include Identity::LoginRequired
  include Tenancy::CurrentOrganization

  class_attribute :first_run_status_resolver,
    instance_accessor: false,
    default: ->(user:) { Tenancy::Public.first_run_status(user: user) }

  layout "authenticated"

  before_action :establish_current_organization!, if: :organization_route?
  before_action :redirect_alias_to_canonical_slug, if: :organization_route?
  permission_required "organization.read", only: :index, if: :organization_route?
  permission_hint "projects.create", only: :index, if: :organization_route?
  before_action :route_first_run

  def index
    @organization_switcher = Tenancy::Public.organization_switcher(user: Current.user)
    @organization_navigation = Tenancy::Public.organization_navigation(user: Current.user)
  end

  private

  def route_first_run
    status = self.class.first_run_status_resolver.call(user: Current.user)
    redirect_to onboarding_path, status: :see_other unless status.returning?
  end

  def organization_route?
    params[:organization_slug].present?
  end

  def redirect_alias_to_canonical_slug
    return if organization_slug_is_canonical?

    redirect_to organization_dashboard_path(Current.organization.slug), status: :moved_permanently
  end
end
