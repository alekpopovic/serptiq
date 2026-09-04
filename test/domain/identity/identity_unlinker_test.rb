# frozen_string_literal: true

require "test_helper"

class IdentityIdentityUnlinkerTest < ActiveSupport::TestCase
  setup do
    @user = create_identity_user
    @google = create_provider_identity(user: @user, provider: "google", provider_subject: "google-subject")
    @github = create_provider_identity(user: @user, provider: "github", provider_subject: "123456")
    @now = [ @google.created_at, @github.created_at ].max.change(usec: 0) + 1.second
    @issued = issue_identity_session(user: @user, at: @now - 1.minute)
  end

  test "unlinks an owned identity and atomically rotates the recent session" do
    result = Identity::IdentityUnlinker.new(clock: -> { @now }).call(
      identity_id: @github.id,
      current_session: @issued.session
    )

    assert_equal "github", result.provider
    assert_not_nil @github.reload.revoked_at
    assert @google.reload.active?
    assert_equal "privilege_changed", @issued.session.reload.revoke_reason
    assert_equal @issued.session.id, result.issued_session.session.rotated_from_id
    assert_not_equal @issued.token, result.issued_session.token
  end

  test "last active identity denial leaves identity and session unchanged" do
    @github.update!(revoked_at: @now)

    assert_no_changes -> { @google.reload.revoked_at } do
      assert_no_difference -> { Identity::Session.count } do
        error = assert_raises(Identity::LastSignInIdentity) do
          unlink(@google)
        end
        assert_equal "last_sign_in_identity", error.reason_code
      end
    end
    assert_nil @issued.session.reload.revoked_at
  end

  test "stale authentication and another user's opaque identity id are denied" do
    @issued.session.update!(authenticated_at: @now - 16.minutes)
    assert_raises(Identity::RecentAuthenticationRequired) { unlink(@github) }
    assert_nil @github.reload.revoked_at

    fresh = issue_identity_session(user: @user, at: @now - 1.minute)
    foreign = create_provider_identity(provider: "google", provider_subject: "foreign-subject")
    error = assert_raises(Identity::InvalidAccountLink) do
      Identity::IdentityUnlinker.new(clock: -> { @now }).call(
        identity_id: foreign.id,
        current_session: fresh.session
      )
    end
    assert_equal "provider_identity_unlink_invalid", error.reason_code
    assert foreign.reload.active?
  end

  private

  def unlink(identity)
    Identity::IdentityUnlinker.new(clock: -> { @now }).call(
      identity_id: identity.id,
      current_session: @issued.session
    )
  end
end
