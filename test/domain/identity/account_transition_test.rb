# frozen_string_literal: true

require "test_helper"

class IdentityAccountTransitionTest < ActiveSupport::TestCase
  setup do
    @now = 1.second.from_now.change(usec: 0)
    @user = create_identity_user
    @session = issue_identity_session(user: @user, at: @now - 1.minute).session
  end

  test "explicit recent linking may reactivate the same owned provider subject" do
    identity = create_provider_identity(
      user: @user, provider: "github", provider_subject: "112233"
    )
    identity.update!(revoked_at: @now)
    observed = normalized_identity(provider: "github", subject: "112233")

    result = transition.call(normalized_identity: observed, link_session: @session)

    assert_equal @user, result
    assert identity.reload.active?
    assert_equal @now, identity.last_authenticated_at
    assert_equal "relinked", identity.profile.fetch("login")
  end

  test "explicit linking cannot attach a second active subject from the same provider" do
    existing = create_provider_identity(
      user: @user, provider: "github", provider_subject: "112233"
    )
    observed = normalized_identity(provider: "github", subject: "445566")

    error = assert_raises(Identity::InvalidAccountLink) do
      transition.call(normalized_identity: observed, link_session: @session)
    end

    assert_equal "provider_already_linked", error.reason_code
    assert_equal existing, Identity::ProviderIdentity.sole
  end

  private

  def transition
    Identity::AccountTransition.new(clock: -> { @now })
  end

  def normalized_identity(provider:, subject:)
    Identity::NormalizedIdentity.new(
      provider: provider,
      subject: subject,
      email: "relinked@example.test",
      email_verified: true,
      profile: { "login" => "relinked" }
    )
  end
end
