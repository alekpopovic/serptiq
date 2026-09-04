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

    def create_oauth_transaction!(provider:, state:, nonce:, pkce_verifier:, return_to:, expires_at:,
      initiator_digest:, link_session: nil)
      OauthTransaction.create_protected!(
        provider: provider,
        state: state,
        nonce: nonce,
        pkce_verifier: pkce_verifier,
        initiator_digest: initiator_digest,
        link_session: link_session,
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

    def resolve_account(normalized_identity:)
      AccountResolver.new.call(normalized_identity: normalized_identity)
    end

    def start_google_authorization!(return_to:, link_intent:, current_session:, initiator_digest:)
      GoogleAuthorizationStarter.from_settings.call(
        return_to: return_to,
        link_intent: link_intent,
        current_session: current_session,
        initiator_digest: initiator_digest
      )
    end

    def complete_google_callback!(callback:, current_session:)
      GoogleCallbackCompleter.from_settings.call(callback: callback, current_session: current_session)
    end

    def start_github_authorization!(return_to:, link_intent:, current_session:, initiator_digest:)
      GithubAuthorizationStarter.from_settings.call(
        return_to: return_to,
        link_intent: link_intent,
        current_session: current_session,
        initiator_digest: initiator_digest
      )
    end

    def complete_github_callback!(callback:, current_session:)
      GithubCallbackCompleter.from_settings.call(callback: callback, current_session: current_session)
    end

    def issue_link_confirmation!(provider:, session:, clock: -> { Time.current })
      LinkConfirmation.new(clock: clock).issue(provider: provider, session: session)
    end

    def verify_link_confirmation!(token:, provider:, session:, clock: -> { Time.current })
      LinkConfirmation.new(clock: clock).verify!(token: token, provider: provider, session: session)
    end

    def unlink_provider_identity!(identity_id:, current_session:, metadata: SessionMetadata.empty,
      clock: -> { Time.current })
      IdentityUnlinker.new(clock: clock).call(
        identity_id: identity_id,
        current_session: current_session,
        metadata: metadata
      )
    end
  end
end
