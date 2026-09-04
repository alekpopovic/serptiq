# frozen_string_literal: true

require "test_helper"

class IdentitySessionManagerTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @user = create_identity_user
    @current = issue_identity_session(user: @user, at: @now - 1.minute)
    @other = issue_identity_session(user: @user, at: @now - 2.minutes)
    @manager = Identity::SessionManager.new(clock: -> { @now })
  end

  test "inventory includes only active sessions for the exact user" do
    revoked = issue_identity_session(user: @user, at: @now - 3.minutes)
    Identity::Public.revoke_session(session: revoked.session, clock: -> { @now - 1.minute })
    issue_identity_session(at: @now - 1.minute)

    inventory = @manager.inventory(user: @user, current_session: @current.session)

    assert_equal [ @current.session.id, @other.session.id ].sort, inventory.map(&:id).sort
    assert inventory.all? { |session| session.user_id == @user.id }
  end

  test "revokes one other session idempotently and never revokes current" do
    assert @manager.revoke_other!(session_id: @other.session.id, current_session: @current.session)
    refute @manager.revoke_other!(session_id: @other.session.id, current_session: @current.session)
    assert_equal "administrative", @other.session.reload.revoke_reason
    assert @current.session.reload.active_at?(@now)

    assert_raises(Identity::SessionManagementDenied) do
      @manager.revoke_other!(session_id: @current.session.id, current_session: @current.session)
    end
  end

  test "foreign and nonexistent opaque ids have the same denial" do
    foreign = issue_identity_session(at: @now - 1.minute)
    ids = [ foreign.session.id, SecureRandom.uuid ]

    reasons = ids.map do |id|
      assert_raises(Identity::SessionManagementDenied) do
        @manager.revoke_other!(session_id: id, current_session: @current.session)
      end.reason_code
    end

    assert_equal [ "session_management_invalid" ], reasons.uniq
    assert foreign.session.reload.active_at?(@now)
  end

  test "all-other revocation preserves the current token and requires recent authentication" do
    third = issue_identity_session(user: @user, at: @now - 3.minutes)

    assert_equal 2, @manager.revoke_all_others!(current_session: @current.session)
    assert @current.session.reload.active_at?(@now)
    assert_not_nil @other.session.reload.revoked_at
    assert_not_nil third.session.reload.revoked_at

    @current.session.update!(authenticated_at: @now - 16.minutes)
    assert_raises(Identity::RecentAuthenticationRequired) do
      @manager.revoke_all_others!(current_session: @current.session)
    end
  end
end
