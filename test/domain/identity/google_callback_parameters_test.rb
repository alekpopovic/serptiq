# frozen_string_literal: true

require "test_helper"

class GoogleCallbackParametersTest < ActiveSupport::TestCase
  test "accepts one exact state and authorization code while ignoring unknown response parameters" do
    state = deterministic_oauth_secrets.state
    callback = Identity::GoogleCallbackParameters.from_query_string(
      URI.encode_www_form(state: state, code: "synthetic-authorization-code", scope: "openid email")
    )

    assert_equal "synthetic-authorization-code", callback.authorization_code!
    assert_nil callback.raise_provider_error!
    refute_includes callback.inspect, state
    refute_includes callback.inspect, callback.code
  end

  test "maps allowlisted provider errors and rejects unknown or mixed outcomes" do
    state = deterministic_oauth_secrets.state
    denied = Identity::GoogleCallbackParameters.new(state: state, code: nil, error: "access_denied")
    unavailable = Identity::GoogleCallbackParameters.new(state: state, code: nil, error: "server_error")
    unknown = Identity::GoogleCallbackParameters.new(state: state, code: nil, error: "invented_error")
    mixed = Identity::GoogleCallbackParameters.new(
      state: state, code: "synthetic-authorization-code", error: "access_denied"
    )

    assert_equal "google_authorization_denied", assert_raises(Identity::ProviderError) {
      denied.raise_provider_error!
    }.reason_code
    assert_equal "google_authorization_unavailable", assert_raises(Identity::ProviderError) {
      unavailable.raise_provider_error!
    }.reason_code
    assert_equal "google_authorization_error_unknown", assert_raises(Identity::ProviderError) {
      unknown.raise_provider_error!
    }.reason_code
    assert_raises(Identity::ProviderError) { mixed.raise_provider_error! }
    assert_raises(Identity::ProviderError) { mixed.authorization_code! }
  end

  test "rejects missing malformed oversized and duplicate critical query parameters" do
    state = deterministic_oauth_secrets.state
    invalid_queries = [
      URI.encode_www_form(code: "synthetic-authorization-code"),
      URI.encode_www_form(state: "short", code: "synthetic-authorization-code"),
      "state=#{state}&state=#{state}&code=synthetic-authorization-code",
      "state=#{state}&code=one&code=two",
      "state=#{state}&error=access_denied&error=server_error",
      "x=#{'a' * Identity::GoogleCallbackParameters::MAX_QUERY_BYTES}"
    ]

    invalid_queries.each do |query|
      assert_raises(Identity::InvalidOauthTransaction) do
        Identity::GoogleCallbackParameters.from_query_string(query)
      end
    end
  end
end
