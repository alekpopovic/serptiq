# frozen_string_literal: true

require "application_system_test_case"

class GithubOauthSignInSystemTest < ApplicationSystemTestCase
  setup do
    @previous_factory = Identity::GithubOauthController.callback_completer_factory
    @now = Time.current.change(usec: 0)
  end

  teardown do
    Identity::GithubOauthController.callback_completer_factory = @previous_factory
  end

  test "signs in through the fake GitHub provider callback" do
    material = create_oauth_transaction(provider: "github", nonce: nil, expires_at: @now + 10.minutes)
    adapter = TestSupport::GithubCallbackAdapterFake.new(
      configuration: build_github_configuration,
      result: github_callback_exchange
    )
    Identity::GithubOauthController.callback_completer_factory = -> {
      Identity::GithubCallbackCompleter.new(adapter: adapter, clock: -> { @now })
    }

    visit github_oauth_callback_path(state: material.fetch(:state), code: "synthetic-github-authorization-code")

    assert_current_path onboarding_path
    assert_text "Create your first organization"
    assert_equal "github", Identity::ProviderIdentity.sole.provider
    assert_equal "1234567", Identity::ProviderIdentity.sole.provider_subject
    assert_equal 1, adapter.calls.length
  end
end
