# frozen_string_literal: true

require "application_system_test_case"

class InvitationSocialLoginSystemTest < ApplicationSystemTestCase
  setup do
    @previous_factory = Identity::GithubOauthController.callback_completer_factory
    @now = Time.current.change(usec: 0)
  end

  teardown do
    Identity::GithubOauthController.callback_completer_factory = @previous_factory
  end

  test "accepts an invitation after a matching fake GitHub sign in" do
    owner = create_organization_for(name: "Social Invite Workspace", slug: "social-invite-workspace")
    issued = Tenancy::IssueInvitation.new(
      clock: -> { @now }, delivery: ->(**) { }
    ).call(actor_membership: owner.membership, email: "github-user@example.test")

    visit invitation_entry_path(token: issued.token)
    assert_current_path sign_in_path, ignore_query: true

    oauth = create_oauth_transaction(
      provider: "github",
      nonce: nil,
      return_to: invitation_review_path,
      expires_at: @now + 10.minutes
    )
    refute_includes oauth.fetch(:transaction).return_to, issued.token
    adapter = TestSupport::GithubCallbackAdapterFake.new(
      configuration: build_github_configuration,
      result: github_callback_exchange
    )
    Identity::GithubOauthController.callback_completer_factory = -> {
      Identity::GithubCallbackCompleter.new(adapter: adapter, clock: -> { @now })
    }

    visit github_oauth_callback_path(
      state: oauth.fetch(:state),
      code: "synthetic-github-authorization-code"
    )
    assert_current_path invitation_review_path
    assert_text "Join Social Invite Workspace"
    click_button "Accept invitation"

    assert_current_path dashboard_path
    assert_text "Invitation accepted."
    identity = Identity::ProviderIdentity.find_by!(provider: "github")
    membership = Tenancy::Membership.find_by!(organization_id: owner.organization.id, user_id: identity.user_id)
    assert membership.active?
    assert issued.invitation.reload.accepted?
  end
end
