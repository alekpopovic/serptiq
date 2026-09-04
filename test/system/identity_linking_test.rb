# frozen_string_literal: true

require "application_system_test_case"

class IdentityLinkingSystemTest < ApplicationSystemTestCase
  setup do
    @previous_github_completer = Identity::GithubOauthController.callback_completer_factory
    @now = 1.second.from_now.change(usec: 0)
  end

  teardown do
    Identity::GithubOauthController.callback_completer_factory = @previous_github_completer
  end

  test "confirms a GitHub link then unlinks it while retaining Google" do
    user = create_identity_user(display_name: "Linked User")
    google = create_provider_identity(
      user: user, provider: "google", provider_subject: "system-google-subject"
    )
    issued = issue_identity_session(user: user, at: @now - 1.minute)
    authenticate_system_browser(issued)

    visit account_security_path
    click_link "Review linking GitHub"
    assert_text "Link GitHub to this account?"
    assert_button "Confirm and link GitHub"

    material = create_oauth_transaction(
      provider: "github",
      nonce: nil,
      link_session: issued.session,
      return_to: account_security_path,
      expires_at: @now + 10.minutes
    )
    install_github_completer
    visit github_oauth_callback_path(
      state: material.fetch(:state),
      code: "system-link-authorization-code"
    )

    assert_current_path account_security_path
    assert_text "GitHub"
    assert_text "Last used to authenticate"
    github = Identity::ProviderIdentity.find_by!(provider: "github")
    assert_equal user.id, github.user_id
    assert_not_nil issued.session.reload.revoked_at

    accept_confirm { click_button "Unlink GitHub" }

    assert_current_path account_security_path
    assert_text "GitHub has been unlinked"
    assert github.reload.revoked_at?
    assert google.reload.active?
  end

  test "denies unlinking the last sign-in identity" do
    user = create_identity_user
    google = create_provider_identity(
      user: user, provider: "google", provider_subject: "last-system-google-subject"
    )
    issued = issue_identity_session(user: user, at: @now - 1.minute)
    authenticate_system_browser(issued)

    visit account_security_path
    accept_confirm { click_button "Unlink Google" }

    assert_text "This account action needs attention"
    assert_text "Request ID:"
    assert google.reload.active?
    assert_nil issued.session.reload.revoked_at
  end

  private

  def install_github_completer
    adapter = TestSupport::GithubCallbackAdapterFake.new(
      configuration: build_github_configuration,
      result: github_callback_exchange
    )
    Identity::GithubOauthController.callback_completer_factory = -> {
      Identity::GithubCallbackCompleter.new(adapter: adapter, clock: -> { @now })
    }
  end
end
