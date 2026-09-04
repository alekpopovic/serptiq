# frozen_string_literal: true

require "test_helper"

class IdentityProviderIdentityTest < ActiveSupport::TestCase
  test "normalizes provider metadata but resolves identity only by stable subject" do
    identity = create_provider_identity(
      provider: " GOOGLE ",
      provider_subject: " stable-subject ",
      email: " Observed@Example.Test ",
      profile: { "name" => "Observed Name", "login" => "mutable-login" }
    )

    assert_equal "google", identity.provider
    assert_equal "stable-subject", identity.provider_subject
    assert_equal "observed@example.test", identity.email
    assert_equal identity, Identity::Public.find_provider_identity(
      provider: "GOOGLE",
      provider_subject: "stable-subject"
    )
    assert_nil Identity::Public.find_provider_identity(provider: "google", provider_subject: "mutable-login")
  end

  test "allows unverified identities without email and rejects verified identities without one" do
    unverified = create_unverified_provider_identity

    assert_nil unverified.email
    refute unverified.email_verified?

    invalid = Identity::ProviderIdentity.new(
      user: create_identity_user,
      provider: "google",
      provider_subject: "verified-without-email",
      email: nil,
      email_verified: true,
      last_authenticated_at: Time.current
    )
    refute invalid.valid?
    assert_includes invalid.errors[:email], "must be present when verified"
  end

  test "same observed email on separate subjects never merges users" do
    google, github = create_colliding_provider_identities

    assert_equal google.email, github.email
    assert_not_equal google.user_id, github.user_id
    assert_not_equal google.provider_subject, github.provider_subject
  end

  test "rejects unknown providers and non-allowlisted or oversized profile values" do
    identity = create_provider_identity

    identity.provider = "attacker-provider"
    refute identity.valid?
    assert_includes identity.errors[:provider], "is not included in the list"

    identity.provider = "google"
    identity.profile = { "access_token" => "must-not-be-stored", "name" => "x" * 3000 }
    refute identity.valid?
    assert_includes identity.errors[:profile], "contains unsupported fields"
    assert_includes identity.errors[:profile], "must contain only bounded text values"
  end

  test "database uniqueness prevents duplicate provider subjects even without model validation" do
    original = create_provider_identity(provider: "github", provider_subject: "provider-user-42")
    duplicate = original.dup
    duplicate.user = create_identity_user

    error = assert_raises(ActiveRecord::RecordNotUnique) do
      Identity::ProviderIdentity.transaction(requires_new: true) do
        duplicate.save!(validate: false)
      end
    end

    assert_kind_of PG::UniqueViolation, error.cause
    assert_equal original.id, Identity::Public.find_provider_identity(
      provider: "github",
      provider_subject: "provider-user-42"
    ).id
  end

  test "one user has at most one active identity per provider while revoked history can remain" do
    user = create_identity_user
    original = create_provider_identity(user: user, provider: "google", provider_subject: "first-google")
    duplicate = Identity::ProviderIdentity.new(
      user: user,
      provider: "google",
      provider_subject: "second-google",
      email_verified: false,
      profile: {},
      last_authenticated_at: Time.current
    )

    refute duplicate.valid?
    assert_includes duplicate.errors[:provider], "has already been taken"
    error = assert_raises(ActiveRecord::RecordNotUnique) do
      Identity::ProviderIdentity.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
    assert_kind_of PG::UniqueViolation, error.cause

    original.update!(revoked_at: Time.current)
    duplicate.save!
    assert duplicate.active?
  end

  test "model and database reject revocation timestamps before identity creation" do
    identity = create_provider_identity
    invalid_time = identity.created_at - 1.second
    identity.revoked_at = invalid_time

    refute identity.valid?
    assert_includes identity.errors[:revoked_at], "must not precede creation"
    error = assert_raises(ActiveRecord::StatementInvalid) do
      Identity::ProviderIdentity.transaction(requires_new: true) do
        identity.update_column(:revoked_at, invalid_time)
      end
    end
    assert_kind_of PG::CheckViolation, error.cause
  ensure
    identity&.reload
  end

  test "database checks reject provider and verified-email states that bypass validations" do
    invalid_provider = Identity::ProviderIdentity.new(
      user: create_identity_user,
      provider: "unknown",
      provider_subject: "subject",
      email_verified: false,
      profile: {},
      last_authenticated_at: Time.current
    )
    provider_error = assert_raises(ActiveRecord::StatementInvalid) do
      Identity::ProviderIdentity.transaction(requires_new: true) do
        invalid_provider.save!(validate: false)
      end
    end
    assert_kind_of PG::CheckViolation, provider_error.cause

    verified_without_email = invalid_provider.dup
    verified_without_email.provider = "google"
    verified_without_email.email_verified = true
    email_error = assert_raises(ActiveRecord::StatementInvalid) do
      Identity::ProviderIdentity.transaction(requires_new: true) do
        verified_without_email.save!(validate: false)
      end
    end
    assert_kind_of PG::CheckViolation, email_error.cause

    unsafe_profile = Identity::ProviderIdentity.new(
      user: create_identity_user,
      provider: "github",
      provider_subject: "unsafe-profile-subject",
      email_verified: false,
      profile: { "access_token" => "must-not-be-stored" },
      last_authenticated_at: Time.current
    )
    profile_error = assert_raises(ActiveRecord::StatementInvalid) do
      Identity::ProviderIdentity.transaction(requires_new: true) do
        unsafe_profile.save!(validate: false)
      end
    end
    assert_kind_of PG::CheckViolation, profile_error.cause
  end
end
