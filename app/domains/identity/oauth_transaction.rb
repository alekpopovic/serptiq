# frozen_string_literal: true

module Identity
  class OauthTransaction < ApplicationRecord
    self.table_name = "oauth_transactions"

    PKCE_VERIFIER_PATTERN = /\A[A-Za-z0-9._~-]{43,128}\z/
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/
    MAX_LIFETIME = 15.minutes

    belongs_to :link_session,
      class_name: "Identity::Session",
      inverse_of: :link_oauth_transactions,
      optional: true

    normalizes :provider, with: ->(value) { value.to_s.strip.downcase }

    validates :provider, inclusion: { in: ProviderIdentity::PROVIDERS }
    validates :state_digest, :pkce_verifier_digest, :initiator_digest,
      presence: true,
      format: { with: DIGEST_PATTERN }
    validates :state_digest, :pkce_verifier_digest, uniqueness: true
    validates :nonce_digest,
      uniqueness: true,
      format: { with: DIGEST_PATTERN },
      allow_nil: true
    validates :pkce_verifier_ciphertext, presence: true, length: { maximum: 4096 }
    validates :return_to, presence: true, length: { maximum: 2048 }
    validates :expires_at, presence: true
    validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :link_intent, inclusion: { in: [ true, false ] }
    validate :return_path_is_safe
    validate :google_nonce_is_present
    validate :expiry_follows_creation
    validate :attempt_metadata_is_consistent
    validate :link_intent_is_bound_to_session

    def self.create_protected!(provider:, state:, nonce:, pkce_verifier:, return_to:, expires_at:,
      initiator_digest:, link_session: nil)
      validate_pkce_verifier!(pkce_verifier)
      create!(
        provider: provider,
        state_digest: SecretDigest.call(state, purpose: "oauth-state"),
        nonce_digest: nonce && SecretDigest.call(nonce, purpose: "oauth-nonce"),
        pkce_verifier_digest: SecretDigest.call(pkce_verifier, purpose: "oauth-pkce"),
        pkce_verifier_ciphertext: ProtectedValue.encrypt(pkce_verifier, purpose: "oauth-pkce"),
        initiator_digest: initiator_digest,
        link_intent: link_session.present?,
        link_session: link_session,
        return_to: SafeReturnPath.call(return_to),
        expires_at: expires_at
      )
    rescue ArgumentError
      raise InvalidOauthTransaction
    end

    def self.validate_pkce_verifier!(value)
      raise ArgumentError, "invalid PKCE verifier" unless PKCE_VERIFIER_PATTERN.match?(value.to_s)
    end
    private_class_method :validate_pkce_verifier!

    def pkce_verifier
      verifier = ProtectedValue.decrypt(pkce_verifier_ciphertext, purpose: "oauth-pkce")
      return verifier if SecretDigest.matches?(verifier, pkce_verifier_digest, purpose: "oauth-pkce")

      raise CorruptOauthTransaction
    end

    def nonce_matches?(nonce)
      nonce_digest.present? && SecretDigest.matches?(nonce, nonce_digest, purpose: "oauth-nonce")
    end

    def open_at?(time)
      consumed_at.nil? && expires_at > time
    end

    private

    def return_path_is_safe
      errors.add(:return_to, "must be an allowlisted local path") unless SafeReturnPath.call(return_to) == return_to
    end

    def google_nonce_is_present
      errors.add(:nonce_digest, "must be present for Google") if provider == "google" && nonce_digest.blank?
    end

    def attempt_metadata_is_consistent
      consistent = (attempt_count == 0 && last_attempted_at.nil?) ||
        (attempt_count.is_a?(Integer) && attempt_count.positive? && last_attempted_at.present?)
      errors.add(:last_attempted_at, "must match attempt count") unless consistent
      return if consumed_at.nil? || (last_attempted_at && consumed_at <= last_attempted_at)

      errors.add(:consumed_at, "must be at or before the last attempt")
    end

    def link_intent_is_bound_to_session
      valid = link_intent? == link_session.present?
      errors.add(:link_session, "must match explicit link intent") unless valid
    end

    def expiry_follows_creation
      reference_time = created_at || Time.current
      return if expires_at.blank?

      if expires_at <= reference_time
        errors.add(:expires_at, "must be in the future")
      elsif expires_at > reference_time + MAX_LIFETIME
        errors.add(:expires_at, "must be within 15 minutes")
      end
    end
  end
end
