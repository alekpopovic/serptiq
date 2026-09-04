# frozen_string_literal: true

module Verification
  class Challenge < ApplicationRecord
    self.table_name = "domain_verifications"

    METHODS = %w[dns_txt html_file meta_tag search_console].freeze
    STATES = %w[pending verified failed expired revoked].freeze
    FAILURE_CATEGORIES = %w[
      proof_missing proof_mismatch provider_unavailable provider_unauthorized unsafe_destination
      malformed_response attempt_limit dns_nxdomain dns_no_record dns_propagating dns_timeout
      dns_transient_failure dns_multiple_records dns_response_limit dns_cname_limit dns_delegation_limit
      http_dns_failure http_timeout http_transport_failure http_redirect_rejected http_redirect_limit
      http_response_too_large http_content_type_rejected duplicate_meta
      provider_scope_revoked provider_property_inaccessible provider_outage provider_ambiguous_match
      provider_no_match provider_insufficient_permission provider_connection_changed
    ].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    belongs_to :environment, class_name: "Properties::Environment"
    has_many :attempts, class_name: "Verification::Attempt",
      foreign_key: :domain_verification_id, inverse_of: :challenge, dependent: :restrict_with_exception

    validates :organization_id, :project_id, :property_id, :environment_id,
      :issued_by_membership_id, :expires_at, presence: true
    validates :method, inclusion: { in: METHODS }
    validates :state, inclusion: { in: STATES }
    validates :challenge_digest, format: { with: DIGEST_PATTERN }
    validates :expected_location, :bound_origin, presence: true, length: { maximum: 2048 }
    validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :failure_category, inclusion: { in: FAILURE_CATEGORIES }, allow_nil: true
    validate :attempt_shape
    validate :lifecycle_shape
    validate :evidence_shape
    validate :stable_binding_is_immutable, on: :update
    validate :search_console_binding_shape

    scope :current, -> { where(state: %w[pending verified]) }

    STATES.each do |value|
      define_method("#{value}?") { state == value }
    end

    def active_at?(at)
      (pending? || verified?) && expires_at > at
    end

    private

    def attempt_shape
      valid = (attempt_count.zero? && attempted_at.nil?) || (attempt_count.positive? && attempted_at.present?)
      errors.add(:attempt_count, "does not match the last attempt") unless valid
    end

    def lifecycle_shape
      valid = case state
      when "pending"
        verified_at.nil? && failed_at.nil? && expired_at.nil? && revoked_at.nil? && failure_category.nil?
      when "verified"
        verified_at.present? && failed_at.nil? && expired_at.nil? && revoked_at.nil? && failure_category.nil?
      when "failed"
        verified_at.nil? && failed_at.present? && expired_at.nil? && revoked_at.nil? && failure_category.present?
      when "expired"
        failed_at.nil? && expired_at.present? && revoked_at.nil? && failure_category.nil?
      when "revoked"
        failed_at.nil? && expired_at.nil? && revoked_at.present? && failure_category.nil?
      end
      errors.add(:state, "does not match lifecycle timestamps") unless valid
    end

    def evidence_shape
      valid = evidence.is_a?(Hash) && JSON.generate(evidence).bytesize <= 4.kilobytes
      errors.add(:evidence, "must be a bounded object") unless valid
    end

    def stable_binding_is_immutable
      %i[id organization_id project_id property_id environment_id issued_by_membership_id method
        challenge_digest expected_location bound_origin integration_connection_id
        provider_property_identifier provider_property_type connection_revision created_at].each do |attribute|
        errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute)
      end
    end

    def search_console_binding_shape
      values = [ integration_connection_id, provider_property_identifier, provider_property_type,
        provider_permission_level, provider_checked_at, connection_revision ]
      if method == "search_console"
        valid = values.all?(&:present?) && provider_property_identifier.to_s.bytesize <= 2048 &&
          provider_property_type.in?(%w[url_prefix domain]) &&
          provider_permission_level.in?(Integrations::Public::SEARCH_CONSOLE_PERMISSION_LEVELS) &&
          connection_revision.to_i.positive?
      else
        valid = values.all?(&:nil?)
      end
      errors.add(:integration_connection_id, "does not match verification method") unless valid
    end
  end
end
