# frozen_string_literal: true

class OrganizationInvitationMailer < ApplicationMailer
  def invitation
    @organization_name = params.fetch(:organization_name)
    @inviter_name = params.fetch(:inviter_name)
    @expires_at = params.fetch(:expires_at)
    @invitation_url = invitation_entry_url(token: params.fetch(:token))
    mail(to: params.fetch(:recipient), subject: "Invitation to #{@organization_name}")
  end
end
