# frozen_string_literal: true

require "test_helper"

class GithubOauthAuthorizationRequestTest < ActionDispatch::IntegrationTest
  setup do
    @previous_factory = Identity::GithubOauthController.authorization_starter_factory
    @now = Time.current.change(usec: 0)
    @sequence = 0
    install_starter
  end

  teardown do
    Identity::GithubOauthController.authorization_starter_factory = @previous_factory
  end

  test "POST creates a protected transaction with exact GitHub state callback and S256 PKCE parameters" do
    redirect_events = []
    subscriber = ->(*arguments) { redirect_events << ActiveSupport::Notifications::Event.new(*arguments).payload }
    ActiveSupport::Notifications.subscribed(subscriber, "redirect_to.action_controller") do
      post github_oauth_authorization_path,
        params: { return_to: "/dashboard" },
        headers: { "REMOTE_ADDR" => "198.51.100.30" }
    end

    assert_response :see_other
    assert_sensitive_headers
    uri = URI(response.location)
    query = Rack::Utils.parse_query(uri.query)
    assert_equal "https", uri.scheme
    assert_equal "github.com", uri.host
    assert_equal "/login/oauth/authorize", uri.path
    assert_equal "synthetic-github-client-id", query.fetch("client_id")
    assert_equal "https://searchops.test/auth/github/callback", query.fetch("redirect_uri")
    assert_equal "read:user user:email", query.fetch("scope")
    assert_equal "S256", query.fetch("code_challenge_method")
    refute query.key?("nonce")

    transaction = Identity::OauthTransaction.sole
    state = query.fetch("state")
    verifier = transaction.pkce_verifier
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    assert_equal "github", transaction.provider
    assert_nil transaction.nonce_digest
    assert Identity::SecretDigest.matches?(state, transaction.state_digest, purpose: "oauth-state")
    assert_equal challenge, query.fetch("code_challenge")
    refute_includes response.location, verifier
    refute_includes response.body, state
    refute_includes response.body, verifier
    assert_empty redirect_events
  end

  test "external return and callback substitution are ignored" do
    post github_oauth_authorization_path,
      params: {
        return_to: "https://attacker.example/phish",
        redirect_uri: "https://attacker.example/callback"
      }

    assert_response :see_other
    query = Rack::Utils.parse_query(URI(response.location).query)
    assert_equal "https://searchops.test/auth/github/callback", query.fetch("redirect_uri")
    assert_equal "/dashboard", Identity::OauthTransaction.sole.return_to
    refute_includes response.location, "attacker.example"
  end

  test "explicit linking binds the exact recent authenticated session" do
    issued = issue_identity_session(at: @now - 1.minute)
    authenticate_request(issued)

    post github_oauth_authorization_path, params: { link: "1" }

    assert_response :see_other
    transaction = Identity::OauthTransaction.sole
    assert transaction.link_intent?
    assert_equal issued.session.id, transaction.link_session_id
  end

  test "GET initiation and excessive outstanding starts are rejected" do
    get github_oauth_authorization_path
    assert_response :not_found

    install_starter(policy: build_oauth_initiation_policy(max_open_per_ip: 1))
    post github_oauth_authorization_path, headers: { "REMOTE_ADDR" => "198.51.100.31" }
    assert_response :see_other
    post github_oauth_authorization_path, headers: { "REMOTE_ADDR" => "198.51.100.31" }, as: :json
    assert_response :too_many_requests
    assert_equal "rate_limited", response.headers.fetch("X-SearchOps-Error-Code")
  end

  private

  def install_starter(policy: build_oauth_initiation_policy)
    Identity::GithubOauthController.authorization_starter_factory = -> {
      build_github_authorization_starter(
        policy: policy,
        clock: -> { @now },
        secret_generator: -> { @sequence += 1; deterministic_oauth_secrets(@sequence) }
      )
    }
  end

  def assert_sensitive_headers
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal "nosniff", response.headers.fetch("X-Content-Type-Options")
    assert_equal "DENY", response.headers.fetch("X-Frame-Options")
  end
end
