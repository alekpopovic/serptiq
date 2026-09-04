# frozen_string_literal: true

module Auditing
  class AuditEvent < ApplicationRecord
    self.table_name = "audit_events"

    ACTOR_TYPES = %w[Membership User System].freeze
    RESULTS = %w[succeeded denied failed ignored].freeze
    ACTION_PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/
    TARGET_TYPE_PATTERN = /\A[A-Z][A-Za-z0-9]{0,47}\z/
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    validates :actor_type, inclusion: { in: ACTOR_TYPES }
    validates :action, format: { with: ACTION_PATTERN }, length: { maximum: 96 }
    validates :target_type, format: { with: TARGET_TYPE_PATTERN }, length: { maximum: 48 }
    validates :result, inclusion: { in: RESULTS }
    validates :occurred_at, :created_at, presence: true
    validates :request_id, :trace_id, :job_id, length: { maximum: 128 }, allow_nil: true
    validates :source_ip_digest, :user_agent_digest,
      format: { with: DIGEST_PATTERN }, allow_nil: true
    validate :actor_shape
    validate :metadata_is_bounded_object

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "audit events are append-only"
    end

    private

    def actor_shape
      valid = case actor_type
      when "Membership"
        organization_id.present? && actor_membership_id.present? && actor_user_id.nil?
      when "User"
        actor_membership_id.nil? && actor_user_id.present?
      when "System"
        actor_membership_id.nil? && actor_user_id.nil?
      else
        false
      end
      errors.add(:actor_type, "does not match actor identifiers") unless valid
    end

    def metadata_is_bounded_object
      valid = metadata.is_a?(Hash) && JSON.generate(metadata).bytesize <= 8.kilobytes
      errors.add(:metadata, "must be a bounded object") unless valid
    end
  end
end
