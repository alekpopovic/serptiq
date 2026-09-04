# frozen_string_literal: true

module Identity
  class GithubCallbackCompleter
    def self.from_settings(settings: Rails.application.config.x.searchops)
      new(adapter: GithubProviderAdapter.from_settings(settings: settings))
    end

    def initialize(adapter:, account_transition: nil, clock: -> { Time.current })
      raise ArgumentError, "GitHub adapter is required" unless adapter.provider == "github"

      @adapter = adapter
      @clock = clock
      @account_transition = account_transition || AccountTransition.new(clock: clock)
    end

    def call(callback:, current_session:)
      transaction = Public.consume_oauth_transaction!(state: callback.state, clock: @clock)
      validate_transaction!(transaction, current_session)
      callback.raise_provider_error!

      input = CallbackInput.new(
        code: callback.authorization_code!,
        redirect_uri: @adapter.configuration.redirect_uri,
        pkce_verifier: transaction.pkce_verifier,
        issued_after: transaction.created_at
      )
      exchange = @adapter.exchange_callback(input)
      validate_exchange!(exchange)
      user = @account_transition.call(
        normalized_identity: exchange.identity,
        link_session: transaction.link_intent? ? current_session : nil
      )
      operation = transaction.link_intent? ? "link" : "sign_in"
      Audit.emit("auth.oauth_callback_completed", outcome: "succeeded", provider: "github", operation: operation)
      OauthCallbackCompletion.new(user: user, return_to: transaction.return_to, operation: operation)
    rescue StandardError => error
      Audit.emit(
        "auth.oauth_callback_rejected",
        outcome: "denied",
        provider: "github",
        operation: "callback",
        reason_code: safe_reason_code(error)
      )
      raise
    end

    private

    def validate_transaction!(transaction, current_session)
      raise InvalidOauthTransaction unless transaction.provider == "github"

      if transaction.link_intent?
        valid = current_session && transaction.link_session_id == current_session.id &&
          current_session.status_at(@clock.call) == :active &&
          current_session.authenticated_at >= @clock.call - SessionPolicy::RECENT_AUTHENTICATION_WINDOW
        raise InvalidAccountLink.new(reason_code: "account_link_session_mismatch") unless valid
      elsif current_session
        raise InvalidOauthTransaction
      end
    end

    def validate_exchange!(exchange)
      valid = exchange.is_a?(CallbackExchange) && exchange.provider == "github" && exchange.oidc_claims.nil?
      raise ProviderError.new(
        category: "malformed_response",
        operation: "callback_exchange",
        reason_code: "github_exchange_invalid"
      ) unless valid
    end

    def safe_reason_code(error)
      error.reason_code if error.respond_to?(:reason_code)
    end
  end
end
