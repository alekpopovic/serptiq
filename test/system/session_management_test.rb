# frozen_string_literal: true

require "application_system_test_case"

class SessionManagementSystemTest < ApplicationSystemTestCase
  test "lists approximate clients and revokes another browser session" do
    now = Time.current.change(usec: 0)
    user = create_identity_user
    current = issue_identity_session(
      user: user,
      at: now - 1.minute,
      metadata: Identity::SessionMetadata.new(ip_address: nil, user_agent: "Mozilla/5.0 Firefox/142.0")
    )
    other = issue_identity_session(
      user: user,
      at: now - 2.minutes,
      metadata: Identity::SessionMetadata.new(ip_address: nil, user_agent: "Mozilla/5.0 (Android; Mobile) Chrome/140.0")
    )
    authenticate_system_browser(current)

    visit account_sessions_path

    assert_text "Active sessions"
    assert_text "Firefox · Desktop"
    assert_text "Chrome · Mobile"
    assert_text "Current session", count: 1
    accept_confirm { click_button "Revoke this session" }

    assert_current_path account_sessions_path
    assert_text "The selected session has been revoked"
    assert_not_nil other.session.reload.revoked_at
    assert current.session.reload.active_at?(now)
  end
end
