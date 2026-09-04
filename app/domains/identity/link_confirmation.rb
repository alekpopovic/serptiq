# frozen_string_literal: true

module Identity
  class LinkConfirmation
    PURPOSE = "identity-provider-link"
    LIFETIME = 5.minutes

    def self.default_verifier
      Rails.application.message_verifier(PURPOSE)
    end

    def initialize(verifier: self.class.default_verifier, clock: -> { Time.current })
      @verifier = verifier
      @clock = clock
    end

    def issue(provider:, session:)
      now = @clock.call
      validate_provider!(provider)
      validate_session!(session, now)

      @verifier.generate(
        {
          "provider" => provider,
          "session_id" => session.id,
          "issued_at" => now.to_i,
          "expires_at" => (now + LIFETIME).to_i
        },
        purpose: PURPOSE
      )
    end

    def verify!(token:, provider:, session:)
      now = @clock.call
      validate_provider!(provider)
      validate_session!(session, now)
      payload = @verifier.verified(token.to_s, purpose: PURPOSE)
      valid = payload.is_a?(Hash) && payload.keys.sort == %w[expires_at issued_at provider session_id] &&
        payload["provider"] == provider && payload["session_id"] == session.id &&
        valid_times?(payload, now)
      raise InvalidAccountLink.new(reason_code: "account_link_confirmation_invalid") unless valid

      true
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise InvalidAccountLink.new(reason_code: "account_link_confirmation_invalid"), cause: nil
    end

    private

    def validate_provider!(provider)
      return if ProviderIdentity::PROVIDERS.include?(provider)

      raise InvalidAccountLink.new(reason_code: "account_link_provider_invalid")
    end

    def validate_session!(session, now)
      active = session&.status_at(now) == :active && session.user.active?
      recent = active && session.authenticated_at >= now - SessionPolicy::RECENT_AUTHENTICATION_WINDOW
      raise RecentAuthenticationRequired unless recent
    end

    def valid_times?(payload, now)
      issued_at = Integer(payload["issued_at"], exception: false)
      expires_at = Integer(payload["expires_at"], exception: false)
      return false unless issued_at && expires_at

      issued_at <= now.to_i && expires_at > now.to_i && expires_at <= issued_at + LIFETIME.to_i
    end
  end
end
