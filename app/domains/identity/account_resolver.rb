# frozen_string_literal: true

module Identity
  class AccountResolver
    def call(normalized_identity:)
      raise ArgumentError, "normalized identity is required" unless normalized_identity.is_a?(NormalizedIdentity)

      existing = ProviderIdentity.find_by(
        provider: normalized_identity.provider,
        provider_subject: normalized_identity.subject
      )
      if existing
        status = existing.active? && existing.user.active? ? :existing : :revoked
        return AccountResolution.new(status: status, provider_identity: existing)
      end

      collision = normalized_identity.email_verified? && normalized_identity.email && email_collision?(normalized_identity.email)
      AccountResolution.new(status: collision ? :explicit_link_required : :new_account)
    end

    private

    def email_collision?(email)
      ProviderIdentity.where(email: email).exists? || User.where(primary_email: email, deleted_at: nil).exists?
    end
  end
end
