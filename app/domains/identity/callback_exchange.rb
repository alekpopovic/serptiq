# frozen_string_literal: true

module Identity
  class CallbackExchange
    attr_reader :identity, :oidc_claims

    def initialize(identity:, oidc_claims: nil)
      @identity = identity
      @oidc_claims = oidc_claims
      validate!
      freeze
    end

    def provider
      identity.provider
    end

    def inspect
      "#<#{self.class.name} provider=#{provider.inspect} identity=#{identity.inspect} " \
        "oidc_claims=#{oidc_claims ? oidc_claims.inspect : 'nil'}>"
    end

    private

    def validate!
      raise ArgumentError, "normalized identity is required" unless identity.is_a?(NormalizedIdentity)
      if provider == "google" && !oidc_claims.is_a?(OidcClaims)
        raise ArgumentError, "Google exchange requires verified OIDC claims"
      end
      if provider == "github" && oidc_claims
        raise ArgumentError, "GitHub OAuth exchange must not fabricate OIDC claims"
      end
    end
  end
end
