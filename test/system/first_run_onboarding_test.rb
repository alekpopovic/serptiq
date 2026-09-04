# frozen_string_literal: true

require "application_system_test_case"

class FirstRunOnboardingSystemTest < ApplicationSystemTestCase
  setup do
    @previous_dashboard_resolver = DashboardController.first_run_status_resolver
    @previous_onboarding_resolver = OnboardingController.first_run_status_resolver
    @previous_github_completer = Identity::GithubOauthController.callback_completer_factory
  end

  teardown do
    DashboardController.first_run_status_resolver = @previous_dashboard_resolver
    OnboardingController.first_run_status_resolver = @previous_onboarding_resolver
    Identity::GithubOauthController.callback_completer_factory = @previous_github_completer
  end

  test "new user is guided toward organization creation and local account details" do
    set_status(:no_organization)
    authenticate_system_browser(issue_identity_session)

    visit dashboard_path

    assert_current_path onboarding_path
    assert_text "Create your first organization"
    assert_link "Review account details"
    assert_link "Set up organization"
    find("body").send_keys(:tab)
    assert_equal "Skip to main content", page.evaluate_script("document.activeElement.textContent.trim()")
  end

  test "returning user with workspace access reaches the dashboard" do
    set_status(:returning)
    authenticate_system_browser(issue_identity_session)

    visit dashboard_path

    assert_current_path dashboard_path
    assert_text "Dashboard"
  end

  test "invited user is routed to invitation-first guidance" do
    set_status(:invited)
    authenticate_system_browser(issue_identity_session)

    visit dashboard_path

    assert_current_path onboarding_path
    assert_text "Review your invitation first"
    assert_text "will not create a separate organization"
  end

  test "provider denial renders an actionable stable-code page without callback details" do
    now = Time.current.change(usec: 0)
    material = create_oauth_transaction(provider: "github", nonce: nil, expires_at: now + 10.minutes)
    detail = "private-provider-detail"
    adapter = TestSupport::GithubCallbackAdapterFake.new(
      configuration: build_github_configuration,
      result: github_callback_exchange
    )
    Identity::GithubOauthController.callback_completer_factory = -> {
      Identity::GithubCallbackCompleter.new(adapter: adapter, clock: -> { now })
    }

    visit github_oauth_callback_path(
      state: material.fetch(:state),
      error: "access_denied",
      error_description: detail
    )

    assert_text "Sign-in was cancelled"
    assert_text "Error code: external_provider_failed"
    assert_link "Start sign-in again"
    assert_no_text detail
    assert_no_text material.fetch(:state)
    assert_empty adapter.calls
  end

  private

  def set_status(kind)
    resolver = ->(user:) { Tenancy::FirstRunStatus.new(kind: kind) }
    DashboardController.first_run_status_resolver = resolver
    OnboardingController.first_run_status_resolver = resolver
  end
end
