# frozen_string_literal: true

require "test_helper"

class AccountSecurityTest < ActionDispatch::IntegrationTest
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
    @user = create_identity_user(display_name: "Security User")
    @google = create_provider_identity(
      user: @user,
      provider: "google",
      provider_subject: "private-google-subject"
    )
    @google.update_column(:last_authenticated_at, @now - 2.minutes)
    @issued = issue_identity_session(user: @user, at: @now - 1.minute)
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
  end

  teardown do
    Shared::Observability.emitter = @previous_emitter
  end

  test "account security requires authentication and lists only safe identity metadata" do
    get account_security_path
    assert_redirected_to sign_in_path(return_to: account_security_path)

    authenticate_request(@issued)
    get account_security_path

    assert_response :success
    assert_includes response.body, "Sign-in identities"
    assert_includes response.body, "Last used to authenticate"
    assert_includes response.body, "Request ID"
    refute_includes response.body, @google.provider_subject
    refute_includes response.body, @issued.token
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "link confirmation is explicit short lived and provider bound" do
    authenticate_request(@issued)
    get confirm_identity_link_path(provider: "github")

    assert_response :success
    assert_includes response.body, "Link GitHub to this account?"
    token = css_select('input[name="link_confirmation"]').sole["value"]
    assert Identity::LinkConfirmation.new.verify!(token: token, provider: "github", session: @issued.session)
    refute_includes emitted_log, token

    assert_no_difference -> { Identity::OauthTransaction.count } do
      post google_oauth_authorization_path,
        params: { link: "1", link_confirmation: token, return_to: account_security_path }
    end
    assert_response :unauthorized
    assert_equal "authentication_required", response.headers.fetch("X-SearchOps-Error-Code")
  end

  test "direct linking without its signed confirmation is denied before OAuth state creation" do
    authenticate_request(@issued)

    assert_no_difference -> { Identity::OauthTransaction.count } do
      post github_oauth_authorization_path,
        params: { link: "1", return_to: account_security_path }
    end

    assert_response :unauthorized
    assert_equal "authentication_required", response.headers.fetch("X-SearchOps-Error-Code")
  end

  test "unlink revokes the identity rotates the exact session and emits a safe audit event" do
    github = create_provider_identity(
      user: @user, provider: "github", provider_subject: "456789"
    )
    github.update_column(:last_authenticated_at, @now - 1.minute)
    authenticate_request(@issued)

    assert_difference -> { Identity::Session.count } => 1 do
      delete provider_identity_path(github)
    end

    assert_response :see_other
    assert_redirected_to account_security_path
    assert_not_nil github.reload.revoked_at
    assert_equal "privilege_changed", @issued.session.reload.revoke_reason
    refute_equal @issued.token, response.cookies.fetch(Identity::SessionCookie.name)
    assert_includes emitted_log, "auth.identity_unlinked"
    assert_includes emitted_log, '"provider":"github"'
    refute_includes emitted_log, github.provider_subject
  end

  test "last identity and foreign opaque id denials are privacy safe and audited with request identifiers" do
    authenticate_request(@issued)

    assert_no_changes -> { @google.reload.revoked_at } do
      delete provider_identity_path(@google)
    end
    assert_response :conflict
    assert_equal "resource_conflict", response.headers.fetch("X-SearchOps-Error-Code")
    request_id = css_select("p").map(&:text).find { |text| text.include?("Request ID:") }.split.last
    assert_includes emitted_log, "auth.identity_unlink_rejected"
    assert_includes emitted_log, "last_sign_in_identity"
    assert_includes emitted_log, request_id

    foreign = create_provider_identity(provider: "github", provider_subject: "987654")
    authenticate_request(@issued)
    delete provider_identity_path(foreign)
    assert_response :unauthorized
    refute_includes response.body, foreign.provider_subject
    refute_includes emitted_log, foreign.provider_subject
    assert foreign.reload.active?
  end

  test "stale authentication is denied and CSRF rejection cannot mutate identities" do
    @issued.session.update!(authenticated_at: @now - 16.minutes)
    github = create_provider_identity(user: @user, provider: "github", provider_subject: "135790")
    authenticate_request(@issued)
    delete provider_identity_path(github)
    assert_response :unauthorized
    assert github.reload.active?

    @issued.session.update!(authenticated_at: @now - 1.minute)
    authenticate_request(@issued)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_changes -> { github.reload.revoked_at } do
      delete provider_identity_path(github)
    end
    assert_response :unprocessable_content
    assert_equal "validation_failed", response.headers.fetch("X-SearchOps-Error-Code")
  ensure
    ActionController::Base.allow_forgery_protection = previous unless previous.nil?
  end

  private

  def emitted_log
    @logger.entries.map(&:last).join("\n")
  end
end
