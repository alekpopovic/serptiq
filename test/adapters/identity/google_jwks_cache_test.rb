# frozen_string_literal: true

require "test_helper"

class GoogleJwksCacheTest < ActiveSupport::TestCase
  test "caches a validated signing key until the bounded TTL expires" do
    now = Time.current.change(usec: 0)
    calls = 0
    cache = Identity::GoogleJwksCache.new(
      fetcher: -> { calls += 1; { "keys" => [ google_jwk ] } },
      ttl: 5.minutes,
      max_keys: 4,
      clock: -> { now }
    )

    first = cache.key_for(TestSupport::GoogleOauthHelpers::TEST_GOOGLE_KEY_ID, algorithm: "RS256")
    second = cache.key_for(TestSupport::GoogleOauthHelpers::TEST_GOOGLE_KEY_ID, algorithm: "RS256")

    assert_same first, second
    assert_equal 1, calls
    assert_equal "RS256", first.algorithm
    assert_match(/key_id=.*algorithm=/, first.inspect)
  end

  test "refreshes once for key rotation and refreshes an expired cache" do
    now = Time.current.change(usec: 0)
    rotated_key = OpenSSL::PKey::RSA.generate(2048)
    payloads = [
      { "keys" => [ google_jwk ] },
      { "keys" => [ google_jwk(key: rotated_key, key_id: "rotated-key") ] },
      { "keys" => [ google_jwk(key: rotated_key, key_id: "rotated-key") ] }
    ]
    calls = 0
    cache = Identity::GoogleJwksCache.new(
      fetcher: -> { calls += 1; payloads.shift },
      ttl: 60,
      max_keys: 4,
      clock: -> { now }
    )

    cache.key_for(TestSupport::GoogleOauthHelpers::TEST_GOOGLE_KEY_ID, algorithm: "RS256")
    rotated = cache.key_for("rotated-key", algorithm: "RS256")
    assert_equal rotated_key.n, rotated.public_key.n
    assert_equal 2, calls

    now += 61.seconds
    cache.key_for("rotated-key", algorithm: "RS256")
    assert_equal 3, calls
  end

  test "bounds an unknown key to two refreshes and rejects unsafe key metadata" do
    calls = 0
    cache = Identity::GoogleJwksCache.new(
      fetcher: -> { calls += 1; { "keys" => [ google_jwk ] } },
      ttl: 5.minutes,
      max_keys: 4
    )

    error = assert_raises(Identity::ProviderError) do
      cache.key_for("unknown-key", algorithm: "RS256")
    end
    assert_equal "google_jwks_key_not_found", error.reason_code
    assert_equal 2, calls
    assert_raises(Identity::ProviderError) do
      cache.key_for(TestSupport::GoogleOauthHelpers::TEST_GOOGLE_KEY_ID, algorithm: "HS256")
    end

    invalid = google_jwk.merge("kty" => "oct")
    invalid_cache = Identity::GoogleJwksCache.new(
      fetcher: -> { { "keys" => [ invalid ] } }, ttl: 60, max_keys: 4
    )
    assert_raises(Identity::ProviderError) do
      invalid_cache.key_for(TestSupport::GoogleOauthHelpers::TEST_GOOGLE_KEY_ID, algorithm: "RS256")
    end
  end

  test "rejects duplicate and excessive JWKS entries" do
    duplicate = Identity::GoogleJwksCache.new(
      fetcher: -> { { "keys" => [ google_jwk, google_jwk ] } }, ttl: 60, max_keys: 4
    )
    error = assert_raises(Identity::ProviderError) do
      duplicate.key_for(TestSupport::GoogleOauthHelpers::TEST_GOOGLE_KEY_ID, algorithm: "RS256")
    end
    assert_equal "google_jwks_duplicate_key_id", error.reason_code

    excessive = Identity::GoogleJwksCache.new(
      fetcher: -> { { "keys" => Array.new(5) { google_jwk } } }, ttl: 60, max_keys: 4
    )
    assert_raises(Identity::ProviderError) do
      excessive.key_for(TestSupport::GoogleOauthHelpers::TEST_GOOGLE_KEY_ID, algorithm: "RS256")
    end
  end
end
