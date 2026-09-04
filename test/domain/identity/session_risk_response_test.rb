# frozen_string_literal: true

require "test_helper"

class IdentitySessionRiskResponseTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @user = create_identity_user
    @current = issue_identity_session(user: @user, at: @now - 1.minute)
    @other = issue_identity_session(user: @user, at: @now - 2.minutes)
    @response = Identity::SessionRiskResponse.new(clock: -> { @now })
  end

  test "identity change hook rotates only the exact current session" do
    issued = @response.after_identity_change!(current_session: @current.session)

    assert_equal @current.session.id, issued.session.rotated_from_id
    assert_equal "privilege_changed", @current.session.reload.revoke_reason
    assert @other.session.reload.active_at?(@now)
  end

  test "ownership and sensitive-role hooks rotate current and revoke every other session" do
    issued = @response.after_ownership_transfer!(current_session: @current.session)

    assert_equal @current.session.id, issued.session.rotated_from_id
    assert_equal "privilege_changed", @other.session.reload.revoke_reason

    newer_other = issue_identity_session(user: @user, at: @now)
    next_issued = @response.after_sensitive_role_change!(current_session: issued.session)
    assert_equal issued.session.id, next_issued.session.rotated_from_id
    assert_equal "privilege_changed", newer_other.session.reload.revoke_reason
  end

  test "suspected compromise revokes all sessions without issuing a replacement" do
    count = assert_no_difference -> { Identity::Session.count } do
      @response.after_suspected_compromise!(user: @user)
    end

    assert_equal 2, count
    assert Identity::Session.where(user_id: @user.id).all?(&:revoked_at?)
  end
end
