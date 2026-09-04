# frozen_string_literal: true

require "test_helper"

class IdentityAccountResolverTest < ActiveSupport::TestCase
  test "resolves only the stable provider and subject pair" do
    stored = create_provider_identity(
      provider: "google",
      provider_subject: "stable-google-subject",
      email: "old-observation@example.test"
    )
    observed = normalized_identity(
      provider: "google",
      subject: "stable-google-subject",
      email: "new-observation@example.test"
    )

    resolution = Identity::Public.resolve_account(normalized_identity: observed)

    assert_equal :existing, resolution.status
    assert_equal stored, resolution.provider_identity
    assert_equal stored.user, resolution.user
    assert_equal "old-observation@example.test", stored.reload.email
  end

  test "returns revoked identity as an explicit decision instead of authenticating it" do
    stored = create_provider_identity(provider: "github", provider_subject: "revoked-github-subject")
    stored.update!(revoked_at: Time.current)

    resolution = Identity::Public.resolve_account(
      normalized_identity: normalized_identity(provider: "github", subject: "revoked-github-subject")
    )

    assert_equal :revoked, resolution.status
    assert_equal stored, resolution.provider_identity
  end

  test "returns an inactive local user as revoked even when the provider identity is active" do
    stored = create_provider_identity(provider: "github", provider_subject: "inactive-user-subject")
    stored.user.update!(suspended_at: Time.current)

    resolution = Identity::Public.resolve_account(
      normalized_identity: normalized_identity(provider: "github", subject: "inactive-user-subject")
    )

    assert_equal :revoked, resolution.status
    assert_equal stored, resolution.provider_identity
  end

  test "verified email collision requires explicit linking and never merges records" do
    existing = create_provider_identity(email: "collision@example.test")
    incoming = normalized_identity(
      provider: "github",
      subject: "different-subject",
      email: "COLLISION@example.test",
      email_verified: true
    )

    assert_no_difference -> { Identity::User.count }, -> { Identity::ProviderIdentity.count } do
      resolution = Identity::Public.resolve_account(normalized_identity: incoming)
      assert_equal :explicit_link_required, resolution.status
      assert_nil resolution.user
    end
    assert_equal existing.user_id, existing.reload.user_id
  end

  test "primary email collision also requires explicit linking while unverified observations do not" do
    create_identity_user(primary_email: "primary-collision@example.test")
    verified = normalized_identity(
      provider: "github", subject: "verified-subject", email: "primary-collision@example.test", email_verified: true
    )
    unverified = normalized_identity(
      provider: "github", subject: "unverified-subject", email: "primary-collision@example.test", email_verified: false
    )

    assert_equal :explicit_link_required, Identity::Public.resolve_account(normalized_identity: verified).status
    assert_equal :new_account, Identity::Public.resolve_account(normalized_identity: unverified).status
  end

  test "new account resolution is a side-effect-free domain decision" do
    incoming = normalized_identity(provider: "google", subject: "brand-new-subject", email: "new@example.test")

    assert_no_difference -> { Identity::User.count }, -> { Identity::ProviderIdentity.count } do
      resolution = Identity::Public.resolve_account(normalized_identity: incoming)
      assert_equal :new_account, resolution.status
      assert_nil resolution.provider_identity
    end
  end

  private

  def normalized_identity(provider:, subject:, email: "observed@example.test", email_verified: true)
    Identity::NormalizedIdentity.new(
      provider: provider,
      subject: subject,
      email: email,
      email_verified: email_verified,
      profile: { "name" => "Untrusted Provider Observation" }
    )
  end
end
