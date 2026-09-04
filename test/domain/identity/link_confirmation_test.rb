# frozen_string_literal: true

require "test_helper"

class IdentityLinkConfirmationTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @confirmation = Identity::LinkConfirmation.new(clock: -> { @now })
    @issued = issue_identity_session(at: @now - 1.minute)
  end

  test "signed confirmation is bound to the intended provider and exact recent session" do
    token = @confirmation.issue(provider: "github", session: @issued.session)

    assert @confirmation.verify!(token: token, provider: "github", session: @issued.session)

    swapped_provider = assert_raises(Identity::InvalidAccountLink) do
      @confirmation.verify!(token: token, provider: "google", session: @issued.session)
    end
    assert_equal "account_link_confirmation_invalid", swapped_provider.reason_code

    another_session = issue_identity_session(user: @issued.session.user, at: @now - 1.minute)
    assert_raises(Identity::InvalidAccountLink) do
      @confirmation.verify!(token: token, provider: "github", session: another_session.session)
    end
  end

  test "tampered expired and stale-session confirmations are rejected" do
    token = @confirmation.issue(provider: "google", session: @issued.session)
    tampered = token.dup.tap { |value| value[-1] = value[-1] == "a" ? "b" : "a" }

    assert_raises(Identity::InvalidAccountLink) do
      @confirmation.verify!(token: tampered, provider: "google", session: @issued.session)
    end

    @now += Identity::LinkConfirmation::LIFETIME
    assert_raises(Identity::InvalidAccountLink) do
      @confirmation.verify!(token: token, provider: "google", session: @issued.session)
    end

    @now -= Identity::LinkConfirmation::LIFETIME
    @issued.session.update!(authenticated_at: @now - Identity::SessionPolicy::RECENT_AUTHENTICATION_WINDOW - 1.second)
    assert_raises(Identity::RecentAuthenticationRequired) do
      @confirmation.verify!(token: token, provider: "google", session: @issued.session)
    end
  end
end
