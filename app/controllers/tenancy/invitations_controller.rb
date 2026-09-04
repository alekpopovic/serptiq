# frozen_string_literal: true

module Tenancy
  class InvitationsController < ApplicationController
    include Identity::LoginRequired
    include CurrentOrganization

    layout "authenticated"
    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "members.read", only: :index
    permission_required "members.invite", only: %i[new create revoke resend]
    permission_hint "members.invite", only: :index

    def index
      @invitations = Invitation.where(organization_id: Current.organization.id)
        .order(created_at: :desc).limit(100)
    end

    def new
      @role_keys = Invitation::ROLE_KEYS
    end

    def create
      Public.issue_invitation(
        actor_membership: Current.membership,
        authorization: authorization_decision!("members.invite"),
        email: params[:email],
        initial_role_key: params[:initial_role_key].presence
      )
      redirect_to organization_invitations_path(Current.organization.slug),
        notice: neutral_delivery_notice, status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @role_keys = Invitation::ROLE_KEYS
      @validation_message = error.record.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end

    def revoke
      Public.revoke_invitation(
        actor_membership: Current.membership,
        authorization: authorization_decision!("members.invite"),
        invitation_id: params[:id]
      )
      redirect_to organization_invitations_path(Current.organization.slug),
        notice: "Invitation revoked.", status: :see_other
    end

    def resend
      Public.resend_invitation(
        actor_membership: Current.membership,
        authorization: authorization_decision!("members.invite"),
        invitation_id: params[:id]
      )
      redirect_to organization_invitations_path(Current.organization.slug),
        notice: neutral_delivery_notice, status: :see_other
    end

    private

    def neutral_delivery_notice
      "If the address can receive mail, a new invitation was sent."
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      destination = action_name == "new" ?
        new_organization_invitation_path(Current.organization.slug) :
        organization_invitations_path(Current.organization.slug)
      redirect_to destination, status: :moved_permanently
    end
  end
end
