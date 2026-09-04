# frozen_string_literal: true

require "test_helper"

class OrganizationInvitationMailerTest < ActionMailer::TestCase
  test "renders a bounded one-time link in both parts" do
    token = Tenancy::InvitationToken.generate
    mail = OrganizationInvitationMailer.with(
      recipient: "recipient@example.test",
      organization_name: "Mailer Workspace",
      inviter_name: "Mailer Owner",
      token: token,
      expires_at: 7.days.from_now
    ).invitation

    assert_equal [ "recipient@example.test" ], mail.to
    assert_equal "Invitation to Mailer Workspace", mail.subject
    assert_includes mail.html_part.body.decoded, token
    assert_includes mail.text_part.body.decoded, token
  end
end
