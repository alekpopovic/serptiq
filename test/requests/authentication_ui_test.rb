# frozen_string_literal: true

require "test_helper"

class AuthenticationUiTest < ActionDispatch::IntegrationTest
  setup do
    @previous_availability = PublicPagesController.provider_availability_resolver
  end

  teardown do
    PublicPagesController.provider_availability_resolver = @previous_availability
  end

  test "configured providers are actionable while unavailable providers remain explicit" do
    PublicPagesController.provider_availability_resolver = -> { { google: true, github: false } }

    get sign_in_path

    assert_response :success
    assert_select "form[action='#{google_oauth_authorization_path}'][method='post']", count: 1
    assert_select "form[action='#{github_oauth_authorization_path}']", count: 0
    assert_select "[role='status']", text: /GitHub sign-in is temporarily unavailable/
    assert_select "input[type='password']", count: 0
  end

  test "sign-in copy distinguishes provider identity from local access and session control" do
    PublicPagesController.provider_availability_resolver = -> { { google: false, github: false } }

    get sign_in_path

    assert_response :success
    assert_select "p[role='status']", count: 2
    assert_includes response.body, "do not automatically grant workspace access"
    assert_includes response.body, "revoke active sessions"
  end
end
