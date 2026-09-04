# frozen_string_literal: true

require "test_helper"
require "json"

class GoogleOauthAuthorizationRequestTest < ActionDispatch::IntegrationTest
  class CaptureLogger
    attr_reader :entries

    def initialize
      @entries = []
    end

    %i[debug info warn error fatal].each do |severity|
      define_method(severity) { |message| entries << [ severity, message ] }
    end
  end

  setup do
    @previous_factory = Identity::GoogleOauthController.authorization_starter_factory
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
    @now = Time.current.change(usec: 0)
    @sequence = 0
    install_starter
  end

  teardown do
    Identity::GoogleOauthController.authorization_starter_factory = @previous_factory
    Shared::Observability.emitter = @previous_emitter
  end

  test "POST creates a protected transaction and redirects with every exact Google OIDC parameter" do
    redirect_events = []
    subscriber = ->(*arguments) { redirect_events << ActiveSupport::Notifications::Event.new(*arguments).payload }
    ActiveSupport::Notifications.subscribed(subscriber, "redirect_to.action_controller") do
      post google_oauth_authorization_path,
        params: { return_to: "/dashboard" },
        headers: { "REMOTE_ADDR" => "198.51.100.10", "User-Agent" => "Synthetic Browser/1.0" }
    end

    assert_response :see_other
    assert_sensitive_headers
    uri = URI(response.location)
    query = Rack::Utils.parse_query(uri.query)
    assert_equal "https", uri.scheme
    assert_equal "accounts.google.com", uri.host
    assert_equal "/o/oauth2/v2/auth", uri.path
    assert_equal "synthetic-google-client-id", query.fetch("client_id")
    assert_equal "https://searchops.test/auth/google/callback", query.fetch("redirect_uri")
    assert_equal "code", query.fetch("response_type")
    assert_equal "openid email profile", query.fetch("scope")
    assert_equal "S256", query.fetch("code_challenge_method")

    transaction = Identity::OauthTransaction.sole
    state = query.fetch("state")
    nonce = query.fetch("nonce")
    verifier = transaction.pkce_verifier
    expected_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    assert Identity::SecretDigest.matches?(state, transaction.state_digest, purpose: "oauth-state")
    assert transaction.nonce_matches?(nonce)
    assert_equal expected_challenge, query.fetch("code_challenge")
    refute_includes response.location, verifier
    [ state, nonce, verifier, query.fetch("code_challenge") ].each do |secret|
      refute_includes response.body, secret
      refute_includes emitted_log, secret
    end
    assert_equal "/dashboard", transaction.return_to
    assert_equal @now + 10.minutes, transaction.expires_at
    assert_equal 64, transaction.initiator_digest.length
    refute_includes transaction.attributes.values.map(&:to_s), "198.51.100.10"

    event = JSON.parse(emitted_log)
    assert_equal "auth.oauth_started", event.fetch("event_name")
    assert_equal "google", event.fetch("provider")
    assert_equal "sign_in", event.fetch("operation")
    assert event.fetch("request_id").present?
    assert_empty redirect_events, "secret-bearing authorization URLs must not enter Rails redirect instrumentation"
  end

  test "external return path falls back and caller cannot supply a redirect URI" do
    post google_oauth_authorization_path,
      params: {
        return_to: "https://attacker.example/phish",
        redirect_uri: "https://attacker.example/oauth/callback"
      }

    assert_response :see_other
    query = Rack::Utils.parse_query(URI(response.location).query)
    assert_equal "https://searchops.test/auth/google/callback", query.fetch("redirect_uri")
    assert_equal "/dashboard", Identity::OauthTransaction.sole.return_to
    refute_includes response.location, "attacker.example"
  end

  test "explicit link intent is bound to the authenticated recent session" do
    issued = issue_identity_session(at: @now - 1.minute)
    authenticate_request(issued)

    post google_oauth_authorization_path, params: { link: "1", return_to: "/dashboard" }

    assert_response :see_other
    transaction = Identity::OauthTransaction.sole
    assert transaction.link_intent?
    assert_equal issued.session.id, transaction.link_session_id
    assert_equal "link", JSON.parse(emitted_log).fetch("operation")
  end

  test "link intent requires authentication and rejects ambiguous input without creating a transaction" do
    post google_oauth_authorization_path, params: { link: "1" }

    assert_response :unauthorized
    assert_equal "authentication_required", response.headers.fetch("X-SearchOps-Error-Code")
    assert_sensitive_headers
    assert_equal 0, Identity::OauthTransaction.count

    post google_oauth_authorization_path, params: { link: "please" }

    assert_response :unprocessable_content
    assert_equal "validation_failed", response.headers.fetch("X-SearchOps-Error-Code")
    assert_equal 0, Identity::OauthTransaction.count
  end

  test "signed-in requests without explicit link intent are rejected" do
    authenticate_request(issue_identity_session(at: @now - 1.minute))

    post google_oauth_authorization_path

    assert_response :unprocessable_content
    assert_equal "validation_failed", response.headers.fetch("X-SearchOps-Error-Code")
    assert_equal 0, Identity::OauthTransaction.count
  end

  test "excess outstanding starts return one generic rate-limit response" do
    install_starter(policy: build_oauth_initiation_policy(max_open_per_ip: 1))

    post google_oauth_authorization_path, headers: { "REMOTE_ADDR" => "198.51.100.20" }, as: :json
    assert_response :see_other
    post google_oauth_authorization_path, headers: { "REMOTE_ADDR" => "198.51.100.20" }, as: :json

    assert_response :too_many_requests
    assert_equal "rate_limited", response.headers.fetch("X-SearchOps-Error-Code")
    assert_equal "Too many requests. Please try again later.", response.parsed_body.fetch("error").fetch("message")
    assert_sensitive_headers
    assert_equal 1, Identity::OauthTransaction.count
  end

  test "authorization start is not exposed as a state-changing GET" do
    get google_oauth_authorization_path

    assert_response :not_found
    assert_equal 0, Identity::OauthTransaction.count
  end

  test "invalid callback carries sensitive-response headers and never renders query secrets" do
    code = "callback-authorization-code-that-is-private"
    state = "callback-state-that-is-private-and-long-enough"

    get google_oauth_callback_path, params: { code: code, state: state }

    assert_response :unauthorized
    assert_sensitive_headers
    refute_includes response.body, code
    refute_includes response.body, state
    refute_includes emitted_log, code
    refute_includes emitted_log, state
  end

  private

  def install_starter(policy: build_oauth_initiation_policy)
    Identity::GoogleOauthController.authorization_starter_factory = -> {
      build_google_authorization_starter(
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

  def emitted_log
    @logger.entries.map(&:last).find { |entry| entry.include?(%q("event_name":"auth.oauth_started")) } ||
      @logger.entries.map(&:last).join("\n")
  end
end
