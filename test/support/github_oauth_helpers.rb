# frozen_string_literal: true

module TestSupport
  module GithubOauthHelpers
    def build_github_configuration(origin: "https://searchops.test")
      definition = Identity::ProviderConfiguration::DEFINITIONS.fetch("github")
      Identity::ProviderConfiguration.new(
        provider: "github",
        client_id: "synthetic-github-client-id",
        credential_available: true,
        issuer: definition.issuer,
        discovery_endpoint: definition.discovery_endpoint,
        authorization_endpoint: definition.authorization_endpoint,
        token_endpoint: definition.token_endpoint,
        jwks_endpoint: definition.jwks_endpoint,
        user_endpoint: definition.user_endpoint,
        emails_endpoint: definition.emails_endpoint,
        application_origin: origin,
        redirect_uri: "#{origin}/auth/github/callback"
      )
    end

    def build_github_authorization_starter(policy: build_oauth_initiation_policy, clock: -> { Time.current },
      secret_generator: -> { deterministic_oauth_secrets })
      Identity::GithubAuthorizationStarter.new(
        adapter: Identity::GithubProviderAdapter.new(configuration: build_github_configuration),
        limiter: Identity::OauthInitiationLimiter.new(policy: policy),
        policy: policy,
        clock: clock,
        secret_generator: secret_generator
      )
    end

    def normalized_github_identity(subject: "1234567", login: "synthetic-login",
      email: "github-user@example.test", email_verified: true)
      Identity::NormalizedIdentity.new(
        provider: "github",
        subject: subject,
        email: email,
        email_verified: email_verified,
        profile: { "login" => login, "name" => "Synthetic GitHub User" }
      )
    end

    def github_callback_exchange(identity: normalized_github_identity)
      Identity::CallbackExchange.new(identity: identity)
    end
  end
end
