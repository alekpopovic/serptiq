# frozen_string_literal: true

module Crawling
  class PressureState < ApplicationRecord
    self.table_name = "crawl_pressure_states"

    SCOPES = %w[global organization scan host].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/
    REASON_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/

    belongs_to :organization, class_name: "Tenancy::Organization", optional: true
    belongs_to :scan, class_name: "Crawling::Scan", optional: true
    belongs_to :disabled_by_user, class_name: "Identity::User", optional: true

    validates :scope_type, inclusion: { in: SCOPES }
    validates :scope_key_digest, format: { with: DIGEST_PATTERN }, uniqueness: { scope: :scope_type }
    validates :host_key_digest, format: { with: DIGEST_PATTERN }, allow_nil: true
    validates :failure_streak, numericality: { only_integer: true, in: 0..20 }
    validates :disabled_reason, format: { with: REASON_PATTERN }, allow_nil: true
    validates :next_fetch_at, presence: true
    validate :scope_shape
    validate :emergency_control_shape

    scope :disabled, -> { where.not(disabled_at: nil) }
    scope :backed_off_at, ->(at) { where("backoff_until > ?", at) }

    def disabled?
      disabled_at.present?
    end

    private

    def scope_shape
      tenant = [ organization_id, project_id, property_id, environment_id, scan_id ]
      valid = case scope_type
      when "global" then tenant.all?(&:nil?) && host_key_digest.nil?
      when "organization" then organization_id.present? && tenant.drop(1).all?(&:nil?) && host_key_digest.nil?
      when "scan" then tenant.all?(&:present?) && host_key_digest.nil?
      when "host" then tenant.all?(&:nil?) && host_key_digest.present?
      else false
      end
      errors.add(:scope_type, "does not match pressure state identifiers") unless valid
    end

    def emergency_control_shape
      values = [ disabled_at, disabled_by_user_id, disabled_reason ]
      valid = values.all?(&:nil?) || (scope_type.in?(%w[global host]) && values.all?(&:present?))
      errors.add(:disabled_at, "does not match emergency control state") unless valid
    end
  end
end
