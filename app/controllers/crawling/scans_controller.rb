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
    permission_required "scans.run", only: :create,
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

    def create
      attributes = scan_request_params
      command = Public.admission_request(
        idempotency_key: request.headers["Idempotency-Key"].presence || attributes.fetch(:idempotency_key),
        source: "manual",
        project_id: @project.id,
        property_id: attributes.fetch(:property_id),
        environment_id: attributes.fetch(:environment_id),
        scan_type: attributes.fetch(:scan_type, "full"),
        baseline_scan_id: attributes[:baseline_scan_id],
        release_id: attributes[:release_id]
      )
      scan = Public.admit_scan(actor_membership: Current.membership, command: command)
      if request.format.json?
        render json: {
          scan: {
            id: scan.id,
            status: scan.status,
            project_id: scan.project_id,
            property_id: scan.property_id,
            environment_id: scan.environment_id
          }
        }, status: :accepted
      else
        redirect_to organization_project_scan_path(
          Current.organization.slug, @project.slug, scan.id
        ), notice: "Scan admitted and queued for processing.", status: :see_other
      end
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

    def scan_request_params
      params.expect(scan_request: %i[
        idempotency_key property_id environment_id scan_type baseline_scan_id release_id
      ]).to_h.symbolize_keys
    end

    def load_project!
      @project = Projects::Project.find_by(
        organization_id: Current.organization.id,
        slug: params[:project_slug]
      )
      raise AccessDenied.new(reason_code: "scan_scope_unavailable") unless @project
    end
  end
end
