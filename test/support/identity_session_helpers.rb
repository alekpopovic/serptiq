# frozen_string_literal: true

module TestSupport
  module IdentitySessionHelpers
    def create_identity_user(**attributes)
      defaults = {
        primary_email: "user-#{SecureRandom.hex(6)}@example.test",
        display_name: "Test User"
      }
      Identity::User.create!(**defaults.merge(attributes))
    end

    def issue_identity_session(user: create_identity_user, at: Time.current, metadata: Identity::SessionMetadata.empty)
      Identity::Public.issue_session(user: user, metadata: metadata, clock: -> { at })
    end

    def create_provider_identity(user: create_identity_user, provider: "google", provider_subject: nil,
      email: "observed@example.test", email_verified: true, profile: {})
      Identity::ProviderIdentity.create!(
        user: user,
        provider: provider,
        provider_subject: provider_subject || "subject-#{SecureRandom.hex(8)}",
        email: email,
        email_verified: email_verified,
        profile: profile,
        last_authenticated_at: Time.current
      )
    end

    def create_verified_provider_identity(**attributes)
      create_provider_identity(**{ email_verified: true }.merge(attributes))
    end

    def create_unverified_provider_identity(**attributes)
      create_provider_identity(**{ email: nil, email_verified: false }.merge(attributes))
    end

    def create_colliding_provider_identities(email: "collision@example.test")
      [
        create_verified_provider_identity(email: email, provider: "google"),
        create_verified_provider_identity(email: email.upcase, provider: "github")
      ]
    end

    def create_oauth_transaction(provider: "google", state: nil, nonce: :default, pkce_verifier: nil,
      return_to: "/dashboard", expires_at: 10.minutes.from_now, initiator_digest: "a" * 64, link_session: nil)
      secrets = {
        state: state || SecureRandom.urlsafe_base64(32, false),
        nonce: nonce == :default ? SecureRandom.urlsafe_base64(32, false) : nonce,
        pkce_verifier: pkce_verifier || SecureRandom.urlsafe_base64(32, false)
      }
      transaction = Identity::Public.create_oauth_transaction!(
        provider: provider,
        initiator_digest: initiator_digest,
        link_session: link_session,
        return_to: return_to,
        expires_at: expires_at,
        **secrets
      )
      secrets.merge(transaction: transaction)
    end

    def authenticate_request(issued_session)
      cookies[Identity::SessionCookie.name] = issued_session.token
    end

    def authenticate_system_browser(issued_session)
      visit root_path
      page.driver.browser.manage.add_cookie(
        name: Identity::SessionCookie.name,
        value: issued_session.token,
        path: "/"
      )
    end

    def link_confirmation_for(provider:, session:, at: Time.current)
      Identity::LinkConfirmation.new(clock: -> { at }).issue(provider: provider, session: session)
    end
  end
end
