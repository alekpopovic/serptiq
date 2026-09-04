# frozen_string_literal: true

require "test_helper"

class GoogleOauthCallbackTest < ActionDispatch::IntegrationTest
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
    @previous_factory = Identity::GoogleOauthController.callback_completer_factory
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
    @now = Time.current.change(usec: 0)
  end

  teardown do
    Identity::GoogleOauthController.callback_completer_factory = @previous_factory
    Shared::Observability.emitter = @previous_emitter
  end

  test "valid callback creates the stable-subject account rotates the browser session and uses stored return path" do
    material = create_oauth_transaction(return_to: "/dashboard/reports", expires_at: @now + 10.minutes)
    adapter = install_completer(exchange: exchange_for(nonce: material.fetch(:nonce)))

    assert_difference -> { Identity::User.count } => 1,
      -> { Identity::ProviderIdentity.count } => 1,
      -> { Identity::Session.count } => 1 do
      get google_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
    end

    assert_response :see_other
    assert_equal "http://www.example.com/dashboard/reports", response.location
    assert_sensitive_headers
    transaction = material.fetch(:transaction).reload
    assert_not_nil transaction.consumed_at
    assert_equal 1, transaction.attempt_count
    identity = Identity::ProviderIdentity.sole
    assert_equal "google", identity.provider
    assert_equal "synthetic-google-subject", identity.provider_subject
    assert_equal identity.user_id, Identity::Session.sole.user_id
    assert response.cookies.fetch(Identity::SessionCookie.name).present?
    assert_equal 1, adapter.calls.length
    assert_includes emitted_log, "auth.oauth_callback_completed"
    [ material.fetch(:state), material.fetch(:nonce), material.fetch(:pkce_verifier), authorization_code ].each do |secret|
      refute_includes emitted_log, secret
    end
  end

  test "matching provider denial consumes state before returning a generic categorized failure" do
    material = create_oauth_transaction(expires_at: @now + 10.minutes)
    adapter = install_completer(exchange: exchange_for(nonce: material.fetch(:nonce)))
    private_description = "provider-description-that-must-not-leak"

    get google_oauth_callback_path,
      params: { state: material.fetch(:state), error: "access_denied", error_description: private_description }

    assert_response :bad_gateway
    assert_equal "external_provider_failed", response.headers.fetch("X-SearchOps-Error-Code")
    assert_sensitive_headers
    assert_not_nil material.fetch(:transaction).reload.consumed_at
    assert_empty adapter.calls
    refute_includes response.body, private_description
    refute_includes emitted_log, material.fetch(:state)
    refute_includes emitted_log, private_description
    assert_includes emitted_log, "google_authorization_denied"
  end

  test "invalid expired duplicate and replayed state never reaches the provider" do
    material = create_oauth_transaction(expires_at: @now + 10.minutes)
    adapter = install_completer(exchange: exchange_for(nonce: material.fetch(:nonce)))

    get google_oauth_callback_path, params: { state: "x" * 43, code: authorization_code }
    assert_response :unauthorized
    assert_nil material.fetch(:transaction).reload.consumed_at

    expired = create_oauth_transaction(expires_at: @now + 5.minutes)
    @now += 6.minutes
    get google_oauth_callback_path, params: { state: expired.fetch(:state), code: authorization_code }
    assert_response :unauthorized
    assert_nil expired.fetch(:transaction).reload.consumed_at

    get google_oauth_callback_path,
      params: { state: material.fetch(:state), code: authorization_code }
    assert_response :see_other
    session_count = Identity::Session.count
    get google_oauth_callback_path,
      params: { state: material.fetch(:state), code: authorization_code }
    assert_response :unauthorized
    assert_equal session_count, Identity::Session.count
    assert_equal 1, adapter.calls.length
  end

  test "verified email collision requires explicit linking and never merges accounts" do
    existing = create_provider_identity(
      provider: "github", provider_subject: "existing-github-subject", email: "collision@example.test"
    )
    material = create_oauth_transaction(expires_at: @now + 10.minutes)
    incoming = normalized_google_identity(email: "collision@example.test", email_verified: true)
    install_completer(exchange: exchange_for(nonce: material.fetch(:nonce), identity: incoming))

    assert_no_difference -> { Identity::User.count }, -> { Identity::ProviderIdentity.count } do
      get google_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
    end

    assert_response :conflict
    assert_equal "resource_conflict", response.headers.fetch("X-SearchOps-Error-Code")
    assert_equal existing.user_id, existing.reload.user_id
    assert_not_nil material.fetch(:transaction).reload.consumed_at
    assert_includes emitted_log, "explicit_account_link_required"
  end

  test "unverified colliding email creates a separate subject account without making it primary" do
    existing = create_provider_identity(
      provider: "github", provider_subject: "existing-github-subject", email: "collision@example.test"
    )
    material = create_oauth_transaction(expires_at: @now + 10.minutes)
    incoming = normalized_google_identity(email: "collision@example.test", email_verified: false)
    install_completer(exchange: exchange_for(nonce: material.fetch(:nonce), identity: incoming))

    assert_difference -> { Identity::User.count } => 1, -> { Identity::ProviderIdentity.count } => 1 do
      get google_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
    end

    assert_response :see_other
    google_identity = Identity::ProviderIdentity.find_by!(provider: "google")
    assert_nil google_identity.user.primary_email
    assert_equal "collision@example.test", google_identity.email
    refute google_identity.email_verified?
    refute_equal existing.user_id, google_identity.user_id
  end

  test "existing stable subject signs into its original user and refreshes only bounded observations" do
    existing = create_provider_identity(
      provider: "google",
      provider_subject: "synthetic-google-subject",
      email: "old-observation@example.test",
      profile: { "name" => "Old Name" }
    )
    material = create_oauth_transaction(expires_at: @now + 10.minutes)
    incoming = normalized_google_identity(email: "new-observation@example.test")
    install_completer(exchange: exchange_for(nonce: material.fetch(:nonce), identity: incoming))

    assert_no_difference -> { Identity::User.count }, -> { Identity::ProviderIdentity.count } do
      assert_difference -> { Identity::Session.count } => 1 do
        get google_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
      end
    end

    assert_response :see_other
    assert_equal existing.user_id, Identity::Session.order(:created_at).last.user_id
    assert_equal "new-observation@example.test", existing.reload.email
    assert_equal({ "name" => "Synthetic Google User", "locale" => "en" }, existing.profile)
    assert_equal @now, existing.last_authenticated_at
  end

  test "revoked stable subject cannot create a session or a replacement identity" do
    revoked = create_provider_identity(
      provider: "google", provider_subject: "synthetic-google-subject", email: "revoked@example.test"
    )
    revoked.update!(revoked_at: revoked.created_at)
    material = create_oauth_transaction(expires_at: @now + 10.minutes)
    install_completer(exchange: exchange_for(nonce: material.fetch(:nonce)))

    assert_no_difference -> { Identity::User.count }, -> { Identity::ProviderIdentity.count } do
      assert_no_difference -> { Identity::Session.count } do
        get google_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
      end
    end

    assert_response :unauthorized
    assert_equal revoked.user_id, revoked.reload.user_id
  end

  test "explicit recent-auth intent links to the exact user and rotates that session" do
    user = create_identity_user(primary_email: "linked@example.test")
    issued = issue_identity_session(user: user, at: @now - 1.minute)
    material = create_oauth_transaction(link_session: issued.session, expires_at: @now + 10.minutes)
    install_completer(exchange: exchange_for(
      nonce: material.fetch(:nonce),
      identity: normalized_google_identity(email: "linked@example.test")
    ))
    authenticate_request(issued)

    assert_no_difference -> { Identity::User.count } do
      assert_difference -> { Identity::ProviderIdentity.count } => 1,
        -> { Identity::Session.count } => 1 do
        get google_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
      end
    end

    assert_response :see_other
    assert_equal user.id, Identity::ProviderIdentity.find_by!(provider: "google").user_id
    assert_not_nil issued.session.reload.revoked_at
    assert_equal "privilege_changed", issued.session.revoke_reason
  end

  test "link intent rejects a different browser session before provider exchange" do
    intended = issue_identity_session(at: @now - 1.minute)
    other = issue_identity_session(at: @now - 1.minute)
    material = create_oauth_transaction(link_session: intended.session, expires_at: @now + 10.minutes)
    adapter = install_completer(exchange: exchange_for(nonce: material.fetch(:nonce)))
    authenticate_request(other)

    get google_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }

    assert_response :unauthorized
    assert_empty adapter.calls
    assert_not_nil material.fetch(:transaction).reload.consumed_at
    assert_equal 0, Identity::ProviderIdentity.count
  end

  test "link intent revalidates recent authentication at callback time" do
    stale = issue_identity_session(at: @now - 16.minutes)
    material = create_oauth_transaction(link_session: stale.session, expires_at: @now + 10.minutes)
    adapter = install_completer(exchange: exchange_for(nonce: material.fetch(:nonce)))
    authenticate_request(stale)

    get google_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }

    assert_response :unauthorized
    assert_empty adapter.calls
    assert_not_nil material.fetch(:transaction).reload.consumed_at
    assert_equal 0, Identity::ProviderIdentity.count
  end

  test "a subject already owned by another user cannot be transferred by link intent" do
    owned = create_provider_identity(provider: "google", provider_subject: "synthetic-google-subject")
    current = issue_identity_session(at: @now - 1.minute)
    material = create_oauth_transaction(link_session: current.session, expires_at: @now + 10.minutes)
    install_completer(exchange: exchange_for(nonce: material.fetch(:nonce)))
    authenticate_request(current)

    assert_no_changes -> { owned.reload.user_id } do
      get google_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
    end

    assert_response :unauthorized
    assert_equal 1, Identity::ProviderIdentity.where(provider: "google").count
    assert_includes emitted_log, "provider_identity_owned_by_another_user"
    refute_includes emitted_log, owned.user_id
    refute_includes response.body, owned.user_id
  end

  private

  def install_completer(exchange:)
    adapter = TestSupport::GoogleCallbackAdapterFake.new(
      configuration: build_google_configuration,
      result: exchange
    )
    Identity::GoogleOauthController.callback_completer_factory = -> {
      Identity::GoogleCallbackCompleter.new(adapter: adapter, clock: -> { @now })
    }
    adapter
  end

  def exchange_for(nonce:, identity: normalized_google_identity)
    claims = Identity::OidcClaims.new(
      issuer: "https://accounts.google.com",
      subject: identity.subject,
      audiences: [ "synthetic-google-client-id" ],
      authorized_party: "synthetic-google-client-id",
      issued_at: @now,
      expires_at: @now + 1.hour,
      nonce: nonce,
      key_id: "synthetic-key",
      algorithm: "RS256"
    )
    Identity::CallbackExchange.new(identity: identity, oidc_claims: claims)
  end

  def normalized_google_identity(email: "google-user@example.test", email_verified: true)
    Identity::NormalizedIdentity.new(
      provider: "google",
      subject: "synthetic-google-subject",
      email: email,
      email_verified: email_verified,
      profile: { "name" => "Synthetic Google User", "locale" => "en" }
    )
  end

  def authorization_code
    "synthetic-authorization-code"
  end

  def assert_sensitive_headers
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
  end

  def emitted_log
    @logger.entries.map(&:last).join("\n")
  end
end
