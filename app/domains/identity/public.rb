# frozen_string_literal: true

module Identity
  module Public
    module_function

    def issue_session(user:, metadata: SessionMetadata.empty, clock: -> { Time.current })
      SessionLifecycle.new(clock: clock).issue(user: user, metadata: metadata)
    end

    def authenticate_session!(token:, metadata: SessionMetadata.empty, clock: -> { Time.current })
      SessionLifecycle.new(clock: clock).authenticate!(token: token, metadata: metadata)
    end

    def rotate_session!(session:, metadata: SessionMetadata.empty, reason: "rotated", clock: -> { Time.current })
      SessionLifecycle.new(clock: clock).rotate!(session: session, metadata: metadata, reason: reason)
    end

    def revoke_session(session:, reason: "logout", clock: -> { Time.current })
      SessionLifecycle.new(clock: clock).revoke(session: session, reason: reason)
    end

    def create_oauth_transaction!(provider:, state:, nonce:, pkce_verifier:, return_to:, expires_at:)
      OauthTransaction.create_protected!(
        provider: provider,
        state: state,
        nonce: nonce,
        pkce_verifier: pkce_verifier,
        return_to: return_to,
        expires_at: expires_at
      )
    end

    def consume_oauth_transaction!(state:, clock: -> { Time.current })
      OauthTransactionConsumer.new(clock: clock).call(state: state)
    end

    def find_provider_identity(provider:, provider_subject:)
      ProviderIdentity.find_by(provider: provider.to_s.downcase, provider_subject: provider_subject.to_s)
    end
  end
end
