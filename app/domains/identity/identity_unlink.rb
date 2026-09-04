# frozen_string_literal: true

module Identity
  IdentityUnlink = Data.define(:provider, :issued_session, :identity_id, :user_id) do
    def initialize(provider:, issued_session:, identity_id:, user_id:)
      raise ArgumentError, "provider is required" unless ProviderIdentity::PROVIDERS.include?(provider)
      raise ArgumentError, "issued session is required" unless issued_session.is_a?(IssuedSession)

      super(
        provider: provider,
        issued_session: issued_session,
        identity_id: identity_id.to_s.freeze,
        user_id: user_id.to_s.freeze
      )
      freeze
    end
  end
end
