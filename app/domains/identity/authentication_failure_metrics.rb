# frozen_string_literal: true

module Identity
  module AuthenticationFailureMetrics
    CATEGORIES = %w[
      account_link
      internal
      oauth_transaction
      provider_denied
      provider_invalid
      provider_transient
      session
    ].freeze

    module_function

    def record(error:, provider:, operation: "callback")
      Audit.emit(
        "auth.failure_categorized",
        outcome: "denied",
        provider: provider,
        operation: operation,
        error_category: category(error)
      )
    end

    def category(error)
      value = case error
      when ProviderError
        provider_category(error)
      when ExpiredOauthTransaction, ConsumedOauthTransaction, InvalidOauthTransaction,
        CorruptOauthTransaction
        "oauth_transaction"
      when AccountLinkRequired, InvalidAccountLink, LastSignInIdentity
        "account_link"
      when AuthenticationRequired, RecentAuthenticationRequired, InvalidSession,
        RevokedSession, ExpiredSession, InactiveUser
        "session"
      else
        "internal"
      end
      raise "unbounded authentication failure category" unless CATEGORIES.include?(value)

      value
    end

    def provider_category(error)
      case error.category
      when "access_denied" then "provider_denied"
      when "malformed_response", "configuration", "credentials_revoked" then "provider_invalid"
      else "provider_transient"
      end
    end
    private_class_method :provider_category
  end
end
