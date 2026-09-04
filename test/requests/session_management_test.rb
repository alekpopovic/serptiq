# frozen_string_literal: true

require "test_helper"

class SessionManagementTest < ActionDispatch::IntegrationTest
  setup do
    @now = Time.current.change(usec: 0)
    @user = create_identity_user
    @current = issue_identity_session(
      user: @user,
      at: @now - 1.minute,
      metadata: Identity::SessionMetadata.new(
        ip_address: "203.0.113.9",
        user_agent: "Mozilla/5.0 Chrome/140.0 Safari/537.36"
      )
    )
    @other = issue_identity_session(
      user: @user,
      at: @now - 2.minutes,
      metadata: Identity::SessionMetadata.new(
        ip_address: "198.51.100.14",
        user_agent: "Mozilla/5.0 (iPhone; Mobile) Version/18.0 Safari/604.1"
      )
    )
    authenticate_request(@current)
  end

  test "inventory shows broad metadata and current marker without tokens IPs or digests" do
    get account_sessions_path

    assert_response :success
    assert_select "article", count: 2
    assert_select ".so-badge", text: "Current session", count: 1
    assert_includes response.body, "Chrome · Desktop"
    assert_includes response.body, "Safari · Mobile"
    assert_includes response.body, "Created"
    assert_includes response.body, "Last activity"
    [ @current.token, @other.token, "203.0.113.9", "198.51.100.14",
      @current.session.token_digest, @other.session.user_agent_digest ].each do |private_value|
      refute_includes response.body, private_value
    end
  end

  test "revoke other invalidates its old token while current remains usable" do
    delete account_session_path(@other.session)

    assert_response :see_other
    assert_redirected_to account_sessions_path
    assert_equal "administrative", @other.session.reload.revoke_reason
    assert_raises(Identity::RevokedSession) do
      Identity::Public.authenticate_session!(token: @other.token, clock: -> { @now })
    end
    assert_equal @current.session.id,
      Identity::Public.authenticate_session!(token: @current.token, clock: -> { @now }).id
  end

  test "all-other revocation preserves only the current session" do
    third = issue_identity_session(user: @user, at: @now - 3.minutes)

    delete other_sessions_path

    assert_response :see_other
    assert @current.session.reload.active_at?(@now)
    assert_not_nil @other.session.reload.revoked_at
    assert_not_nil third.session.reload.revoked_at
  end

  test "foreign and nonexistent IDs are anti-enumerated and cannot revoke current" do
    foreign = issue_identity_session(at: @now - 1.minute)

    [ foreign.session.id, SecureRandom.uuid, @current.session.id ].each do |id|
      authenticate_request(@current)
      delete account_session_path(id)
      assert_response :unauthorized
      assert_equal "authentication_required", response.headers.fetch("X-SearchOps-Error-Code")
    end

    assert foreign.session.reload.active_at?(@now)
    assert @current.session.reload.active_at?(@now)
  end

  test "stale authentication and CSRF rejection leave every session unchanged" do
    @current.session.update!(authenticated_at: @now - 16.minutes)
    delete account_session_path(@other.session)
    assert_response :unauthorized
    assert @other.session.reload.active_at?(@now)

    @current.session.update!(authenticated_at: @now - 1.minute)
    authenticate_request(@current)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    delete account_session_path(@other.session)
    assert_response :unprocessable_content
    assert @other.session.reload.active_at?(@now)
  ensure
    ActionController::Base.allow_forgery_protection = previous unless previous.nil?
  end
end
