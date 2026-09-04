# frozen_string_literal: true

require "test_helper"

class IdentityOauthAuthorizationSecretsTest < ActiveSupport::TestCase
  test "generates unique high-entropy URL-safe state nonce and PKCE material" do
    attempts = 100.times.map { Identity::OauthAuthorizationSecrets.generate }

    %i[state nonce pkce_verifier pkce_challenge].each do |attribute|
      values = attempts.map { |attempt| attempt.public_send(attribute) }
      assert_equal 100, values.uniq.length
      assert values.all? { |value| value.match?(/\A[A-Za-z0-9_-]+\z/) }
    end
    assert attempts.all? { |attempt| attempt.state.length == 43 && attempt.nonce.length == 43 }
    assert attempts.all? { |attempt| attempt.pkce_verifier.length == 86 && attempt.pkce_challenge.length == 43 }
    assert attempts.all? { |attempt| attempt.pkce_verifier != attempt.pkce_challenge }
  end

  test "supports deterministic entropy injection and computes the RFC 7636 S256 challenge" do
    bytes = [ "s" * 32, "n" * 32, "v" * 64 ]
    secrets = Identity::OauthAuthorizationSecrets.generate(random_bytes: ->(length) {
      value = bytes.shift
      assert_equal length, value.bytesize
      value
    })
    expected = Base64.urlsafe_encode64(Digest::SHA256.digest(secrets.pkce_verifier), padding: false)

    assert_equal expected, secrets.pkce_challenge
    assert_empty bytes
  end

  test "redacts every secret from diagnostic representation" do
    secrets = deterministic_oauth_secrets

    [ secrets.state, secrets.nonce, secrets.pkce_verifier, secrets.pkce_challenge ].each do |value|
      refute_includes secrets.inspect, value
    end
  end

  test "rejects short malformed or non URL-safe material" do
    assert_raises(ArgumentError) do
      Identity::OauthAuthorizationSecrets.new(state: "short", nonce: "n" * 43, pkce_verifier: "v" * 64)
    end
    assert_raises(ArgumentError) do
      Identity::OauthAuthorizationSecrets.new(state: "s" * 43, nonce: "n" * 42 + "+", pkce_verifier: "v" * 64)
    end
    assert_raises(ArgumentError) do
      Identity::OauthAuthorizationSecrets.new(state: "s" * 43, nonce: "n" * 43, pkce_verifier: "v" * 42)
    end
  end
end
