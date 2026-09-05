# frozen_string_literal: true

module Crawling
  class ScansController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :load_project!

    permission_required "scans.read", only: %i[index show],
      scope: -> { { project: @project } }
    permission_required "scans.cancel", only: :cancel,
      scope: -> { { project: @project } }
    permission_hint "scans.cancel", only: :show,
      scope: -> { { project: @project } }

    def index
      @scan_page = Public.scan_page(
        actor_membership: Current.membership,
        project_id: @project.id,
        number: params[:page]
      )
    end

    def show
      @scan = Public.scan_details(
        actor_membership: Current.membership,
        project_id: @project.id,
        scan_id: params[:scan_id]
      )
    end

    def cancel
      scan = Public.request_scan_cancellation(
        actor_membership: Current.membership,
        project_id: @project.id,
        scan_id: params[:scan_id]
      )
      redirect_to organization_project_scan_path(
        Current.organization.slug, @project.slug, scan.id
      ), notice: "Scan cancellation was recorded.", status: :see_other
    end

    private

    def load_project!
      @project = Projects::Project.find_by(
        organization_id: Current.organization.id,
        slug: params[:project_slug]
      )
      raise AccessDenied.new(reason_code: "scan_scope_unavailable") unless @project
    end
  end
end
