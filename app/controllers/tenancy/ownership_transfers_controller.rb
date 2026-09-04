# frozen_string_literal: true

module Tenancy
  class OwnershipTransfersController < ApplicationController
    include Identity::LoginRequired
    include CurrentOrganization

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "organization.transfer", only: %i[show create]

    def show
      prepare_form
    end

    def create
      result = Public.transfer_ownership(
        actor_membership: Current.membership,
        target_membership_id: params[:target_membership_id],
        current_session: Current.session,
        session_metadata: Identity::SessionMetadata.from_request(request),
        authorization: authorization_decision!("organization.transfer"),
        confirmation: params[:confirmation]
      )
      accept_issued_identity_session!(result.issued_session)
      redirect_to dashboard_path,
        notice: "Ownership transferred. Your permissions and active sessions were updated.",
        status: :see_other
    rescue OwnershipTransferConfirmationInvalid
      @validation_message = "Confirm the exact transfer statement before continuing."
      prepare_form
      render :show, status: :unprocessable_content
    end

    private

    def prepare_form
      @candidates = Public.ownership_transfer_candidates(
        actor_membership: Current.membership,
        authorization: authorization_decision!("organization.transfer")
      )
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_ownership_transfer_path(Current.organization.slug),
        status: :moved_permanently
    end
  end
end
