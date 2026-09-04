# frozen_string_literal: true

require "test_helper"

class AuthenticationSecurityTest < ActionDispatch::IntegrationTest
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
    @now = Time.current.change(usec: 0)
    @previous_google_completer = Identity::GoogleOauthController.callback_completer_factory
    @previous_session_limiter = Identity::SessionsController.rate_limiter_factory
    @previous_account_limiter = Identity::AccountSecurityController.rate_limiter_factory
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
  end

  teardown do
    Identity::GoogleOauthController.callback_completer_factory = @previous_google_completer
    Identity::SessionsController.rate_limiter_factory = @previous_session_limiter
    Identity::AccountSecurityController.rate_limiter_factory = @previous_account_limiter
    Shared::Observability.emitter = @previous_emitter
  end

  test "state PKCE and nonce are protected while replay and open redirects are rejected" do
    secrets = deterministic_oauth_secrets
    material = create_oauth_transaction(
      state: secrets.state,
      nonce: secrets.nonce,
      pkce_verifier: secrets.pkce_verifier,
      return_to: "https://attacker.example/collect",
      expires_at: @now + 10.minutes
    )
    transaction = material.fetch(:transaction)

    assert_equal "/dashboard", transaction.return_to
    assert transaction.nonce_matches?(secrets.nonce)
    refute transaction.nonce_matches?("attacker-#{'n' * 40}")
    assert_equal secrets.pkce_verifier, transaction.pkce_verifier
    [ secrets.state, secrets.nonce, secrets.pkce_verifier ].each do |secret|
      refute_includes transaction.attributes.values.map(&:to_s), secret
    end

    assert_equal transaction, Identity::Public.consume_oauth_transaction!(state: secrets.state, clock: -> { @now })
    assert_raises(Identity::ConsumedOauthTransaction) do
      Identity::Public.consume_oauth_transaction!(state: secrets.state, clock: -> { @now })
    end
    assert_raises(Identity::InvalidOauthTransaction) do
      Identity::Public.consume_oauth_transaction!(state: "invalid-#{'s' * 40}", clock: -> { @now })
    end

    corrupted = create_oauth_transaction(expires_at: @now + 10.minutes).fetch(:transaction)
    replacement = deterministic_oauth_secrets(2).pkce_verifier
    corrupted.update_column(
      :pkce_verifier_ciphertext,
      Identity::ProtectedValue.encrypt(replacement, purpose: "oauth-pkce")
    )
    assert_raises(Identity::CorruptOauthTransaction) { corrupted.pkce_verifier }
  end

  test "OIDC validation rejects a nonce mismatch before identity resolution" do
    secrets = deterministic_oauth_secrets
    input = Identity::CallbackInput.new(
      code: "synthetic-authorization-code",
      redirect_uri: build_google_configuration.redirect_uri,
      pkce_verifier: secrets.pkce_verifier,
      nonce_digest: Identity::SecretDigest.call(secrets.nonce, purpose: "oauth-nonce"),
      issued_after: @now - 1.minute
    )
    cache = Identity::GoogleJwksCache.new(
      fetcher: -> { { "keys" => [ google_jwk ] } },
      ttl: 5.minutes,
      max_keys: 4,
      clock: -> { @now }
    )
    validator = Identity::GoogleIdTokenValidator.new(
      configuration: build_google_configuration,
      jwks_cache: cache,
      clock_skew: 60,
      max_token_lifetime: 2.hours,
      clock: -> { @now }
    )
    token = google_id_token(claims: google_id_token_claims(
      now: @now,
      nonce: "different-#{'n' * 32}"
    ))

    error = assert_raises(Identity::ProviderError) do
      validator.call(token: token, callback_input: input)
    end
    assert_equal "malformed_response", error.category
    assert_equal 0, Identity::User.count
  end

  test "session rotation prevents fixation and verified email collision never merges users" do
    fixed = issue_identity_session(at: @now - 1.minute)
    rotated = Identity::Public.rotate_session!(session: fixed.session, clock: -> { @now })

    refute_equal fixed.token, rotated.token
    assert_raises(Identity::RevokedSession) do
      Identity::Public.authenticate_session!(token: fixed.token, clock: -> { @now })
    end
    assert_equal fixed.session.user_id,
      Identity::Public.authenticate_session!(token: rotated.token, clock: -> { @now }).user_id

    existing = create_provider_identity(email: "collision@example.test")
    incoming = Identity::NormalizedIdentity.new(
      provider: "github",
      subject: "different-stable-subject",
      email: "COLLISION@example.test",
      email_verified: true
    )
    assert_no_difference -> { Identity::User.count }, -> { Identity::ProviderIdentity.count } do
      assert_equal :explicit_link_required,
        Identity::Public.resolve_account(normalized_identity: incoming).status
    end
    assert_equal existing.user_id, existing.reload.user_id
  end

  test "callback failure limit is generic temporary and emits only bounded categories" do
    install_google_completer
    private_state = "private-state-#{'s' * 32}"

    10.times do
      get google_oauth_callback_path,
        params: { state: private_state, code: "private-code" },
        headers: { "REMOTE_ADDR" => "198.51.100.45" }
      assert_response :unauthorized
    end
    get google_oauth_callback_path,
      params: { state: private_state, code: "private-code" },
      headers: { "REMOTE_ADDR" => "198.51.100.45" }

    assert_response :too_many_requests
    assert_equal "rate_limited", response.headers.fetch("X-SearchOps-Error-Code")
    assert_includes 1..300, Integer(response.headers.fetch("Retry-After"))
    assert_includes response.body, "Please wait before trying again"
    refute_includes response.body, private_state
    refute_includes emitted_log, private_state
    refute_includes emitted_log, "private-code"
    assert_includes emitted_log, "auth.failure_categorized"
    assert_includes emitted_log, '"error_category":"oauth_transaction"'
    assert_includes emitted_log, "auth.rate_limit_decision"
  end

  test "session and account security actions have independent session-bound limits" do
    user = create_identity_user
    current = issue_identity_session(user: user, at: @now - 1.minute)
    first_other = issue_identity_session(user: user, at: @now - 2.minutes)
    second_other = issue_identity_session(user: user, at: @now - 3.minutes)
    authenticate_request(current)
    Identity::SessionsController.rate_limiter_factory = -> {
      limiter_for("session_action_session", limit: 1)
    }

    delete account_session_path(first_other.session)
    assert_response :see_other
    delete account_session_path(second_other.session)
    assert_response :too_many_requests
    assert second_other.session.reload.active_at?(@now)
    assert_equal "rate_limited", response.headers.fetch("X-SearchOps-Error-Code")

    Identity::AccountSecurityController.rate_limiter_factory = -> {
      limiter_for("account_security_session", limit: 1)
    }
    get confirm_identity_link_path(provider: "github")
    assert_response :success
    account_bucket = Identity::AuthenticationRateLimitBucket.find_by!(scope: "account_security_session")
    assert_equal 1, account_bucket.request_count
    get confirm_identity_link_path(provider: "github")
    assert_equal 1, Identity::AuthenticationRateLimitBucket.where(scope: "account_security_session").count
    assert_equal 2, account_bucket.reload.request_count
    assert_response :too_many_requests
    assert_includes 1..60, Integer(response.headers.fetch("Retry-After"))
  end

  test "redaction filters callback secrets and provider-controlled descriptions" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(
      "state" => "private-state",
      "code" => "private-code",
      "nonce" => "private-nonce",
      "pkce_verifier" => "private-verifier",
      "error_description" => "private-provider-description"
    )

    assert_equal [ "[FILTERED]" ], filtered.values.uniq
  end

  private

  def limiter_for(scope, limit:)
    policy = Identity::AuthenticationRateLimitPolicy.new(
      rules: { scope => Identity::AuthenticationRateLimitPolicy::Rule.new(limit, 1.minute) }
    )
    Identity::AuthenticationRateLimiter.new(policy: policy, clock: -> { @now })
  end

  def install_google_completer
    adapter = TestSupport::GoogleCallbackAdapterFake.new(
      configuration: build_google_configuration,
      result: RuntimeError.new("adapter should not be reached")
    )
    Identity::GoogleOauthController.callback_completer_factory = -> {
      Identity::GoogleCallbackCompleter.new(adapter: adapter, clock: -> { @now })
    }
  end

  def emitted_log
    @logger.entries.map(&:last).join("\n")
  end
end
