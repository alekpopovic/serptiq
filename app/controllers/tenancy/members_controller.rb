# frozen_string_literal: true

module Tenancy
  class MembersController < ApplicationController
    include Identity::LoginRequired
    include CurrentOrganization

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "members.read", only: %i[index show]
    permission_required "members.update", only: %i[suspend reactivate]
    permission_required "members.remove", only: :remove
    permission_hint "members.update", only: :show
    permission_hint "members.remove", only: :show

    def index
      @membership_page = Public.membership_page(
        actor_membership: Current.membership,
        authorization: authorization_decision!("members.read"),
        page: params[:page]
      )
    end

    def show
      @membership = Public.membership_detail(
        actor_membership: Current.membership,
        authorization: authorization_decision!("members.read"),
        membership_id: params[:id]
      )
    end

    def suspend
      change_status("suspend", "Member suspended. Their active sessions were revoked.")
    end

    def reactivate
      change_status("reactivate", "Member reactivated. They must sign in again.")
    end

    def remove
      change_status("remove", "Member removed. Historical attribution was retained.")
    end

    private

    def change_status(operation, notice)
      Public.change_membership_status(
        actor_membership: Current.membership,
        authorization: authorization_decision!(operation == "remove" ? "members.remove" : "members.update"),
        target_membership_id: params[:id],
        operation: operation
      )
      redirect_to organization_member_path(Current.organization.slug, params[:id]),
        notice: notice, status: :see_other
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      destination = if action_name == "index"
        organization_members_path(Current.organization.slug)
      else
        organization_member_path(Current.organization.slug, params[:id])
      end
      redirect_to destination, status: :moved_permanently
    end
  end
end
