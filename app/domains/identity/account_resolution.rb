# frozen_string_literal: true

module Identity
  class AccountResolution
    STATUSES = %i[existing revoked explicit_link_required new_account].freeze

    attr_reader :status, :provider_identity

    def initialize(status:, provider_identity: nil)
      @status = status.to_sym
      @provider_identity = provider_identity
      validate!
      freeze
    end

    def user
      provider_identity&.user
    end

    def inspect
      "#<#{self.class.name} status=#{status.inspect} provider_identity_id=#{provider_identity&.id.inspect}>"
    end

    private

    def validate!
      raise ArgumentError, "invalid account resolution status" unless STATUSES.include?(status)
      needs_identity = %i[existing revoked].include?(status)
      if needs_identity != provider_identity.is_a?(ProviderIdentity)
        raise ArgumentError, "account resolution identity does not match status"
      end
    end
  end
end
