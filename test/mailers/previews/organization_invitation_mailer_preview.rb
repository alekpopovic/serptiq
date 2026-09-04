# frozen_string_literal: true

class OrganizationInvitationMailerPreview < ActionMailer::Preview
  def invitation
    OrganizationInvitationMailer.with(
      recipient: "alex@example.test",
      organization_name: "Northstar SEO",
      inviter_name: "Morgan Owner",
      token: Tenancy::InvitationToken.generate,
      expires_at: 7.days.from_now
    ).invitation
  end
end
