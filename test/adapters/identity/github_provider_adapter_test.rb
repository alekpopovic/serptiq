# frozen_string_literal: true

require "test_helper"

class GithubProviderAdapterTest < ActiveSupport::TestCase
  class FakeHttpClient
    attr_reader :calls

    def initialize(post: [], objects: [], arrays: [])
      @post = Array(post)
      @objects = Array(objects)
      @arrays = Array(arrays)
      @calls = []
    end

    def post_form_json(**request)
      calls << request.deep_dup.merge(method: :post)
      take(@post)
    end

    def get_json(**request)
      calls << request.deep_dup.merge(method: :get_object)
      take(@objects)
    end

    def get_json_array(**request)
      calls << request.deep_dup.merge(method: :get_array)
      take(@arrays)
    end

    private

    def take(queue)
      value = queue.shift
      raise "unexpected fake HTTP call" if value.nil?
      raise value if value.is_a?(Exception)

      value.deep_dup
    end
  end

  setup do
    @secrets = deterministic_oauth_secrets
    @access_token = "synthetic-github-access-token-that-is-private"
  end

  test "builds the exact GitHub PKCE authorization request without OIDC fields" do
    adapter = Identity::GithubProviderAdapter.new(configuration: build_github_configuration)
    request = adapter.authorization_request(
      state: @secrets.state,
      code_challenge: @secrets.pkce_challenge
    )
    query = Rack::Utils.parse_query(request.uri.query)

    assert_equal "https://github.com/login/oauth/authorize", request.uri.to_s.split("?").first
    assert_equal "synthetic-github-client-id", query.fetch("client_id")
    assert_equal "https://searchops.test/auth/github/callback", query.fetch("redirect_uri")
    assert_equal "read:user user:email", query.fetch("scope")
    assert_equal @secrets.state, query.fetch("state")
    assert_equal @secrets.pkce_challenge, query.fetch("code_challenge")
    assert_equal "S256", query.fetch("code_challenge_method")
    refute query.key?("nonce")
    refute query.key?("response_type")
    assert_raises(ArgumentError) do
      adapter.authorization_request(
        state: @secrets.state,
        code_challenge: @secrets.pkce_challenge,
        nonce: @secrets.nonce
      )
    end
  end

  test "exchanges exact code and PKCE fields then uses numeric ID and verified private primary email" do
    http = FakeHttpClient.new(
      post: [ token_response ],
      objects: [ profile_response(email: nil) ],
      arrays: [ [ email_entry(email: "Private@Example.Test", visibility: "private") ] ]
    )
    adapter = build_adapter(http)

    exchange = adapter.exchange_callback(callback_input)

    assert_equal "github", exchange.provider
    assert_equal "7654321", exchange.identity.subject
    assert_equal "private@example.test", exchange.identity.email
    assert exchange.identity.email_verified?
    assert_nil exchange.oidc_claims
    assert_equal({
      client_id: "synthetic-github-client-id",
      client_secret: "synthetic-github-client-secret",
      code: "synthetic-github-authorization-code",
      redirect_uri: "https://searchops.test/auth/github/callback",
      code_verifier: @secrets.pkce_verifier
    }, http.calls.first.fetch(:form))
    assert_equal "application/json", http.calls.first.fetch(:headers).fetch("Accept")
    assert_equal [
      URI("https://github.com/login/oauth/access_token"),
      URI("https://api.github.com/user"),
      URI("https://api.github.com/user/emails?per_page=100&page=1")
    ], http.calls.map { |call| call.fetch(:uri) }
    http.calls.drop(1).each do |call|
      assert_equal "Bearer #{@access_token}", call.fetch(:headers).fetch("Authorization")
      assert_equal "2026-03-10", call.fetch(:headers).fetch("X-GitHub-Api-Version")
    end
    refute_includes adapter.inspect, @access_token
    refute_includes adapter.inspect, "synthetic-github-client-secret"
    refute_includes exchange.inspect, @access_token
  end

  test "treats absent scope and public email as an unverified observation without email lookup" do
    http = FakeHttpClient.new(
      post: [ token_response(scope: "read:user") ],
      objects: [ profile_response(email: "public@example.test") ]
    )

    identity = build_adapter(http).exchange_callback(callback_input).identity

    assert_equal "public@example.test", identity.email
    refute identity.email_verified?
    assert_equal %i[post get_object], http.calls.map { |call| call.fetch(:method) }
  end

  test "handles absent private and unverified primary emails without inventing authority" do
    cases = [
      [ [], nil, false ],
      [ [ email_entry(email: "unverified@example.test", verified: false, visibility: "private") ],
        "unverified@example.test", false ]
    ]

    cases.each do |emails, expected_email, expected_verified|
      http = FakeHttpClient.new(
        post: [ token_response ],
        objects: [ profile_response(email: nil) ],
        arrays: [ emails ]
      )
      identity = build_adapter(http).exchange_callback(callback_input).identity

      expected_email ? assert_equal(expected_email, identity.email) : assert_nil(identity.email)
      assert_equal expected_verified, identity.email_verified?
    end
  end

  test "changed mutable login preserves the same stable numeric subject" do
    first_http = FakeHttpClient.new(
      post: [ token_response(scope: "read:user") ], objects: [ profile_response(login: "old-login") ]
    )
    second_http = FakeHttpClient.new(
      post: [ token_response(scope: "read:user") ], objects: [ profile_response(login: "new-login") ]
    )

    first = build_adapter(first_http).exchange_callback(callback_input).identity
    second = build_adapter(second_http).exchange_callback(callback_input).identity

    assert_equal first.subject, second.subject
    refute_equal first.profile.fetch("login"), second.profile.fetch("login")
  end

  test "maps token denial bad credentials and provider failures to stable categories" do
    cases = {
      "bad_verification_code" => [ "access_denied", "github_authorization_code_rejected" ],
      "incorrect_client_credentials" => [ "credentials_revoked", "github_client_credentials_rejected" ],
      "redirect_uri_mismatch" => [ "configuration", "github_provider_redirect_mismatch" ],
      "unexpected_error" => [ "malformed_response", "github_token_error_unknown" ]
    }

    cases.each do |provider_error, (category, reason_code)|
      http = FakeHttpClient.new(post: [ { "error" => provider_error, "error_description" => @access_token } ])
      error = assert_raises(Identity::ProviderError) { build_adapter(http).exchange_callback(callback_input) }
      assert_equal category, error.category
      assert_equal reason_code, error.reason_code
      refute_includes error.inspect, @access_token
    end
  end

  test "rejects malformed user email and callback responses" do
    malformed_cases = [
      FakeHttpClient.new(post: [ token_response ], objects: [ profile_response(id: "7654321") ]),
      FakeHttpClient.new(post: [ token_response ], objects: [ profile_response(login: "") ]),
      FakeHttpClient.new(
        post: [ token_response ], objects: [ profile_response ],
        arrays: [ [ email_entry.merge("primary" => "yes") ] ]
      ),
      FakeHttpClient.new(post: [ token_response.merge("token_type" => "mac") ])
    ]

    malformed_cases.each do |http|
      error = assert_raises(Identity::ProviderError) { build_adapter(http).exchange_callback(callback_input) }
      assert_equal "malformed_response", error.category
    end
  end

  test "rejects callback redirect substitution before code exchange" do
    http = FakeHttpClient.new(post: [ token_response ])
    input = Identity::CallbackInput.new(
      code: "synthetic-github-authorization-code",
      redirect_uri: "https://searchops.test/other-callback",
      pkce_verifier: @secrets.pkce_verifier
    )

    error = assert_raises(Identity::ProviderError) { build_adapter(http).exchange_callback(input) }

    assert_equal "github_redirect_uri_mismatch", error.reason_code
    assert_empty http.calls
  end

  private

  def build_adapter(http)
    Identity::GithubProviderAdapter.new(
      configuration: build_github_configuration,
      client_secret: "synthetic-github-client-secret",
      http_client: http
    )
  end

  def callback_input
    Identity::CallbackInput.new(
      code: "synthetic-github-authorization-code",
      redirect_uri: build_github_configuration.redirect_uri,
      pkce_verifier: @secrets.pkce_verifier,
      issued_after: Time.current - 1.minute
    )
  end

  def token_response(scope: "read:user,user:email")
    { "access_token" => @access_token, "token_type" => "bearer", "scope" => scope }
  end

  def profile_response(id: 7_654_321, login: "mutable-login", email: nil)
    {
      "id" => id,
      "login" => login,
      "type" => "User",
      "name" => "Synthetic GitHub User",
      "avatar_url" => "https://avatars.example.test/user.png",
      "email" => email
    }
  end

  def email_entry(email: "github-user@example.test", verified: true, primary: true, visibility: "public")
    { "email" => email, "verified" => verified, "primary" => primary, "visibility" => visibility }
  end
end
