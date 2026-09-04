# frozen_string_literal: true

module Auditing
  class AuditEventsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    layout "authenticated"
    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "audit_log.read", only: :index
    permission_required "audit_log.export", only: :export

    def index
      @filters = audit_filters
      @audit_page = Public.audit_page(
        organization_id: Current.organization.id,
        authorization: authorization_decision!("audit_log.read"),
        filters: @filters,
        page: params[:page]
      )
    end

    def export
      Public.export!(
        organization_id: Current.organization.id,
        authorization: authorization_decision!("audit_log.export")
      )
    end

    private

    def audit_filters
      params.fetch(:filter, {}).permit(:action, :actor_membership_id, :result, :target_type).to_h
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      destination = action_name == "export" ?
        organization_audit_export_path(Current.organization.slug) :
        organization_audit_events_path(Current.organization.slug)
      redirect_to destination, status: :moved_permanently
    end
  end
end
