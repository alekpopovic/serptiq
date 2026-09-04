# frozen_string_literal: true

module Identity
  class RevokedProviderIdentity < Error
    def initialize
      super(reason_code: "provider_identity_revoked")
    end
  end
end
