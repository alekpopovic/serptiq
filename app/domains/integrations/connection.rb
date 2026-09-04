# frozen_string_literal: true

module Integrations
  class Connection < ApplicationRecord
    self.table_name = "integration_connections"

    PROVIDERS = %w[search_console].freeze
    STATES = %w[connected healthy degraded reauthorization_required revoked].freeze
    CONSENT_KINDS = %w[search_console_oauth].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    validates :organization_id, :connected_by_membership_id, :external_account_id,
      :consented_at, presence: true
    validates :provider, inclusion: { in: PROVIDERS }
    validates :state, inclusion: { in: STATES }
    validates :consent_kind, inclusion: { in: CONSENT_KINDS }
    validates :consent_digest, format: { with: DIGEST_PATTERN }
    validates :external_account_id, length: { maximum: 255 }
    validates :credential_revision, numericality: { only_integer: true, greater_than: 0 }
    validate :scopes_shape
    validate :lifecycle_shape

    scope :available_for_verification, -> { where(state: %w[connected healthy degraded]) }

    def reference
      ConnectionReference.new(
        id: id,
        organization_id: organization_id,
        provider: provider,
        external_account_id: external_account_id,
        granted_scopes: granted_scopes,
        state: state,
        credential_revision: credential_revision,
        consented_at: consented_at
      )
    end

    private

    def scopes_shape
      valid = granted_scopes.is_a?(Array) && granted_scopes.length <= 20 &&
        granted_scopes.uniq == granted_scopes && granted_scopes.all? do |scope|
          scope.is_a?(String) && scope == scope.strip && scope.bytesize.between?(1, 255)
        end
      errors.add(:granted_scopes, "must be a bounded unique string array") unless valid
    end

    def lifecycle_shape
      valid = state == "revoked" ? revoked_at.present? : revoked_at.nil?
      errors.add(:state, "does not match revocation timestamp") unless valid
    end
  end
end
