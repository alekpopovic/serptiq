# frozen_string_literal: true

require "test_helper"

class AuthenticationSessionsRequestTest < ActionDispatch::IntegrationTest
  test "anonymous HTML is sent to sign in with an allowlisted return path" do
    get dashboard_path, params: { unsafe: "https://attacker.example" }

    assert_redirected_to sign_in_path(return_to: "/dashboard")
    assert_nil Current.user
    assert_nil Current.session
  end

  test "anonymous JSON receives the stable authentication error" do
    get dashboard_path(format: :json)

    assert_response :unauthorized
    assert_equal "authentication_required", response.parsed_body.dig("error", "code")
  end

  test "an active PostgreSQL session establishes identity for the request and is then cleared" do
    issued = issue_identity_session
    authenticate_request(issued)

    get dashboard_path

    assert_response :success
    assert_select "p", text: /server-side session is active/
    assert_select "form[action='#{logout_path}']"
    assert_nil Current.user
    assert_nil Current.session
  end

  test "expired and revoked cookies are rejected and removed" do
    started_at = 31.days.ago
    expired = issue_identity_session(at: started_at)
    authenticate_request(expired)

    get dashboard_path

    assert_redirected_to sign_in_path(return_to: "/dashboard")
    assert_includes Array(response.headers.fetch("set-cookie")).join("\n"), "searchops_session="

    reset!
    revoked = issue_identity_session
    Identity::Public.revoke_session(session: revoked.session)
    authenticate_request(revoked)

    get dashboard_path

    assert_redirected_to sign_in_path(return_to: "/dashboard")
    assert_includes Array(response.headers.fetch("set-cookie")).join("\n"), "searchops_session="
  end

  test "logout revokes the server record and deletes the browser cookie" do
    issued = issue_identity_session
    authenticate_request(issued)

    delete logout_path

    assert_redirected_to root_path
    assert_equal "logout", issued.session.reload.revoke_reason
    assert_includes Array(response.headers.fetch("set-cookie")).join("\n"), "searchops_session="
    assert_nil Current.user
    assert_nil Current.session

    follow_redirect!
    assert_select "div[role='status']", text: /signed out/
  end

  test "signed-in users cannot revisit sign in and external returns fall back safely" do
    issued = issue_identity_session
    authenticate_request(issued)

    get sign_in_path, params: { return_to: "https://attacker.example/phish" }

    assert_redirected_to dashboard_path
  end
end
