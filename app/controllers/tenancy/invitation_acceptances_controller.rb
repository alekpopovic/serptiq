# frozen_string_literal: true

module Tenancy
  class InvitationAcceptancesController < ApplicationController
    include Identity::LoginRequired

    layout "authenticated"
    authorization_exempt :show, :create, reason: "verified_token_bound_acceptance"
    before_action :set_sensitive_headers
    rescue_from InvitationAccessDenied, RemovedMembershipReactivationDenied,
      Authorization::AssignmentDenied, ActiveRecord::RecordNotFound,
      with: :render_unavailable

    def show
      @invitation = Public.review_invitation(token: invitation_cookie.read, user: Current.user)
    end

    def create
      membership = Authorization::Public.accept_invitation(
        token: invitation_cookie.read,
        user: Current.user,
        rate_limit_key: request.remote_ip
      )
      invitation_cookie.delete
      rotate_current_session!(reason: "privilege_changed")
      destination = if Authorization::Public.policy(
        actor_membership: membership,
        organization: membership.organization
      ).allowed?(permission_key: "organization.read")
        organization_dashboard_path(membership.organization.slug)
      else
        dashboard_path
      end
      redirect_to destination,
        notice: "Invitation accepted.", status: :see_other
    end

    private

    def invitation_cookie
      @invitation_cookie ||= InvitationCookie.new(cookies)
    end

    def render_unavailable
      invitation_cookie.delete
      render :unavailable, layout: "application", status: :forbidden
    end

    def set_sensitive_headers
      response.headers["Cache-Control"] = "no-store, max-age=0"
      response.headers["Pragma"] = "no-cache"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Frame-Options"] = "DENY"
    end
  end
end
