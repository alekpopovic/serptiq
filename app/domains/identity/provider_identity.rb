# frozen_string_literal: true

require "json"

module Identity
  class ProviderIdentity < ApplicationRecord
    self.table_name = "identities"

    PROVIDERS = %w[google github].freeze
    PROFILE_KEYS = %w[name login avatar_url locale].freeze
    SUBJECT_PATTERN = /\A[!-~]+\z/

    belongs_to :user, class_name: "Identity::User", inverse_of: :provider_identities

    normalizes :provider, with: ->(value) { value.to_s.strip.downcase }
    normalizes :provider_subject, with: ->(value) { value.to_s.strip }
    normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }

    validates :provider, inclusion: { in: PROVIDERS }
    validates :provider_subject,
      presence: true,
      length: { maximum: 255 },
      format: { with: SUBJECT_PATTERN }
    validates :email,
      format: { with: URI::MailTo::EMAIL_REGEXP },
      length: { maximum: 320 },
      allow_nil: true
    validates :email_verified, inclusion: { in: [ true, false ] }
    validates :last_authenticated_at, presence: true
    validates :provider_subject, uniqueness: { scope: :provider }
    validate :verified_email_is_present
    validate :profile_is_allowlisted

    def active?
      revoked_at.nil?
    end

    private

    def verified_email_is_present
      errors.add(:email, "must be present when verified") if email_verified? && email.blank?
    end

    def profile_is_allowlisted
      unless profile.is_a?(Hash)
        errors.add(:profile, "must be an object")
        return
      end

      unknown_keys = profile.keys.map(&:to_s) - PROFILE_KEYS
      errors.add(:profile, "contains unsupported fields") if unknown_keys.any?
      errors.add(:profile, "must contain only bounded text values") unless bounded_profile_values?
      errors.add(:profile, "is too large") if JSON.generate(profile).bytesize > 8192
    rescue JSON::GeneratorError
      errors.add(:profile, "must contain JSON values")
    end

    def bounded_profile_values?
      profile.values.all? { |value| value.nil? || (value.is_a?(String) && value.bytesize <= 2048) }
    end
  end
end
