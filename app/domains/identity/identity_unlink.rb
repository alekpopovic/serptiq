# frozen_string_literal: true

module Identity
  IdentityUnlink = Data.define(:provider, :issued_session) do
    def initialize(provider:, issued_session:)
      raise ArgumentError, "provider is required" unless ProviderIdentity::PROVIDERS.include?(provider)
      raise ArgumentError, "issued session is required" unless issued_session.is_a?(IssuedSession)

      super
      freeze
    end
  end
end
