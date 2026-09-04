# frozen_string_literal: true

module Identity
  class Session < ApplicationRecord
    self.table_name = "sessions"

    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/
    REVOKE_REASONS = %w[logout rotated privilege_changed user_inactive administrative].freeze

    belongs_to :user, class_name: "Identity::User", inverse_of: :sessions
    belongs_to :rotated_from,
      class_name: "Identity::Session",
      inverse_of: :rotations,
      optional: true
    has_many :rotations,
      class_name: "Identity::Session",
      foreign_key: :rotated_from_id,
      inverse_of: :rotated_from,
      dependent: :restrict_with_exception
    has_many :link_oauth_transactions,
      class_name: "Identity::OauthTransaction",
      foreign_key: :link_session_id,
      inverse_of: :link_session,
      dependent: :restrict_with_exception

    validates :token_digest, presence: true, uniqueness: true, format: { with: DIGEST_PATTERN }
    validates :ip_address_digest, :user_agent_digest,
      format: { with: DIGEST_PATTERN }, allow_nil: true
    validates :authenticated_at, :last_seen_at, :expires_at, presence: true
    validates :revoke_reason, inclusion: { in: REVOKE_REASONS }, allow_nil: true
    validates :client_name, inclusion: { in: SessionMetadata::CLIENT_NAMES }
    validates :device_type, inclusion: { in: SessionMetadata::DEVICE_TYPES }
    validate :expiry_follows_last_seen
    validate :revocation_fields_are_consistent
    validate :authentication_precedes_last_seen

    def status_at(now, idle_timeout: SessionPolicy::IDLE_TIMEOUT)
      return :revoked if revoked_at?
      return :expired unless expires_at > now
      return :idle_expired unless last_seen_at > now - idle_timeout
      return :user_inactive unless user.active?

      :active
    end

    def active_at?(now)
      status_at(now) == :active
    end

    private

    def expiry_follows_last_seen
      return if expires_at.blank? || last_seen_at.blank? || expires_at > last_seen_at

      errors.add(:expires_at, "must be after last seen")
    end

    def revocation_fields_are_consistent
      return if revoked_at.present? == revoke_reason.present?

      errors.add(:revoked_at, "and revoke reason must be set together")
    end

    def authentication_precedes_last_seen
      return if authenticated_at.blank? || last_seen_at.blank? || authenticated_at <= last_seen_at

      errors.add(:authenticated_at, "must be at or before last seen")
    end
  end
end
