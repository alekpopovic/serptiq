# frozen_string_literal: true

require "test_helper"

class GithubOauthCallbackTest < ActionDispatch::IntegrationTest
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
    @previous_factory = Identity::GithubOauthController.callback_completer_factory
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
    @now = Time.current.change(usec: 0)
  end

  teardown do
    Identity::GithubOauthController.callback_completer_factory = @previous_factory
    Shared::Observability.emitter = @previous_emitter
  end

  test "valid callback creates a stable numeric-subject account and fresh application session" do
    material = create_oauth_transaction(provider: "github", nonce: nil, expires_at: @now + 10.minutes)
    adapter = install_completer

    assert_difference -> { Identity::User.count } => 1,
      -> { Identity::ProviderIdentity.count } => 1,
      -> { Identity::Session.count } => 1 do
      get github_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
    end

    assert_response :see_other
    assert_equal "http://www.example.com/dashboard", response.location
    assert_sensitive_headers
    identity = Identity::ProviderIdentity.sole
    assert_equal "github", identity.provider
    assert_equal "1234567", identity.provider_subject
    assert_equal 1, adapter.calls.length
    assert_nil adapter.calls.sole.nonce
    assert_nil adapter.calls.sole.nonce_digest
    assert_not_nil material.fetch(:transaction).reload.consumed_at
    [ material.fetch(:state), material.fetch(:pkce_verifier), authorization_code ].each do |secret|
      refute_includes emitted_log, secret
    end
  end

  test "state replay and provider callback mismatch cannot create a second transition" do
    material = create_oauth_transaction(provider: "github", nonce: nil, expires_at: @now + 10.minutes)
    adapter = install_completer

    get github_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
    assert_response :see_other
    counts = [ Identity::User.count, Identity::ProviderIdentity.count, Identity::Session.count ]
    get github_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
    assert_response :unauthorized
    assert_equal counts, [ Identity::User.count, Identity::ProviderIdentity.count, Identity::Session.count ]
    assert_equal 1, adapter.calls.length

    google = create_oauth_transaction(provider: "google", expires_at: @now + 10.minutes)
    get github_oauth_callback_path, params: { state: google.fetch(:state), code: authorization_code }
    assert_response :unauthorized
    assert_not_nil google.fetch(:transaction).reload.consumed_at
    assert_equal 1, adapter.calls.length
  end

  test "matching provider denial consumes state without code exchange or detail leakage" do
    material = create_oauth_transaction(provider: "github", nonce: nil, expires_at: @now + 10.minutes)
    adapter = install_completer
    detail = "private-provider-detail"

    get github_oauth_callback_path,
      params: { state: material.fetch(:state), error: "access_denied", error_description: detail }

    assert_response :bad_gateway
    assert_equal "external_provider_failed", response.headers.fetch("X-SearchOps-Error-Code")
    assert_empty adapter.calls
    assert_not_nil material.fetch(:transaction).reload.consumed_at
    refute_includes response.body, detail
    refute_includes emitted_log, detail
    refute_includes emitted_log, material.fetch(:state)
    assert_includes emitted_log, "github_authorization_denied"
  end

  test "verified email collision requires explicit recent-session linking" do
    existing = create_provider_identity(
      provider: "google", provider_subject: "existing-google", email: "collision@example.test"
    )
    denied = create_oauth_transaction(provider: "github", nonce: nil, expires_at: @now + 10.minutes)
    install_completer(identity: normalized_github_identity(email: "collision@example.test"))

    assert_no_difference -> { Identity::User.count }, -> { Identity::ProviderIdentity.count } do
      get github_oauth_callback_path, params: { state: denied.fetch(:state), code: authorization_code }
    end
    assert_response :conflict
    assert_equal existing.user_id, existing.reload.user_id

    issued = issue_identity_session(user: existing.user, at: @now - 1.minute)
    linked = create_oauth_transaction(
      provider: "github", nonce: nil, link_session: issued.session, expires_at: @now + 10.minutes
    )
    authenticate_request(issued)
    assert_difference -> { Identity::ProviderIdentity.count } => 1 do
      get github_oauth_callback_path, params: { state: linked.fetch(:state), code: authorization_code }
    end
    assert_response :see_other
    assert_equal existing.user_id, Identity::ProviderIdentity.find_by!(provider: "github").user_id
    assert_not_nil issued.session.reload.revoked_at
  end

  test "existing numeric subject survives login rename and only refreshes profile observations" do
    existing = create_provider_identity(
      provider: "github",
      provider_subject: "1234567",
      email: "github-user@example.test",
      profile: { "login" => "old-login" }
    )
    material = create_oauth_transaction(provider: "github", nonce: nil, expires_at: @now + 10.minutes)
    install_completer(identity: normalized_github_identity(login: "renamed-login"))

    assert_no_difference -> { Identity::User.count }, -> { Identity::ProviderIdentity.count } do
      get github_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }
    end

    assert_response :see_other
    assert_equal existing.user_id, Identity::Session.order(:created_at).last.user_id
    assert_equal "renamed-login", existing.reload.profile.fetch("login")
  end

  test "unverified GitHub email remains observational and is not promoted to primary email" do
    material = create_oauth_transaction(provider: "github", nonce: nil, expires_at: @now + 10.minutes)
    install_completer(identity: normalized_github_identity(
      email: "unverified@example.test", email_verified: false
    ))

    get github_oauth_callback_path, params: { state: material.fetch(:state), code: authorization_code }

    assert_response :see_other
    identity = Identity::ProviderIdentity.find_by!(provider: "github")
    assert_equal "unverified@example.test", identity.email
    refute identity.email_verified?
    assert_nil identity.user.primary_email
  end

  private

  def install_completer(identity: normalized_github_identity)
    adapter = TestSupport::GithubCallbackAdapterFake.new(
      configuration: build_github_configuration,
      result: github_callback_exchange(identity: identity)
    )
    Identity::GithubOauthController.callback_completer_factory = -> {
      Identity::GithubCallbackCompleter.new(adapter: adapter, clock: -> { @now })
    }
    adapter
  end

  def authorization_code
    "synthetic-github-authorization-code"
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
