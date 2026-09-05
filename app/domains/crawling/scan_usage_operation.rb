# frozen_string_literal: true

module Crawling
  class ScanUsageOperation < ApplicationRecord
    self.table_name = "crawl_scan_usage_operations"

    KINDS = %w[http_fetch rendered_page lighthouse_page artifact].freeze
    STATES = %w[reserved billed not_billable].freeze
    OUTCOMES = %w[accepted failed canceled rejected abandoned].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/
    METER_KEY_PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/

    belongs_to :scan, class_name: "Crawling::Scan", inverse_of: :usage_operations
    belongs_to :quota_allocation, class_name: "Usage::QuotaAllocation",
      foreign_key: :usage_quota_allocation_id, optional: true
    belongs_to :usage_event, class_name: "Usage::UsageEvent", optional: true

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :operation_kind, :state, :attempted_at, presence: true
    validates :operation_kind, inclusion: { in: KINDS }
    validates :state, inclusion: { in: STATES }
    validates :outcome, inclusion: { in: OUTCOMES }, allow_nil: true
    validates :source_key_digest, :request_checksum,
      format: { with: DIGEST_PATTERN }
    validates :completion_checksum, format: { with: DIGEST_PATTERN }, allow_nil: true
    validates :reserved_credits, numericality: { greater_than_or_equal_to: 0 }
    validate :identifier_shapes
    validate :meter_shape
    validate :lifecycle_shape
    validate :metadata_shape

    scope :pending, -> { where(state: "reserved") }

    def reserved?
      state == "reserved"
    end

    def billed?
      state == "billed"
    end

    def not_billable?
      state == "not_billable"
    end

    private

    def identifier_shapes
      %i[organization_id project_id property_id environment_id scan_id].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
    end

    def meter_shape
      valid = if operation_kind == "artifact"
        meter_key.nil? && meter_rate_version.nil? && applied_weight.nil? &&
          reserved_credits&.zero? && usage_quota_allocation_id.nil?
      else
        METER_KEY_PATTERN.match?(meter_key.to_s) && meter_rate_version.to_i.positive? &&
          applied_weight&.positive? && reserved_credits == applied_weight &&
          usage_quota_allocation_id.present?
      end
      errors.add(:operation_kind, "does not match its meter snapshot") unless valid
    end

    def lifecycle_shape
      valid = case state
      when "reserved"
        outcome.nil? && completion_checksum.nil? && usage_event_id.nil? && finished_at.nil?
      when "billed"
        operation_kind != "artifact" && outcome == "accepted" && completion_checksum.present? &&
          usage_event_id.present? && finished_at.present?
      when "not_billable"
        outcome.present? && completion_checksum.present? && usage_event_id.nil? && finished_at.present? &&
          (operation_kind == "artifact" || outcome != "accepted")
      else
        false
      end
      errors.add(:state, "does not match operation lifecycle") unless valid
    end

    def metadata_shape
      valid = metadata.is_a?(Hash) && JSON.generate(metadata).bytesize <= 2.kilobytes
      errors.add(:metadata, "must be a bounded object") unless valid
    rescue JSON::GeneratorError
      errors.add(:metadata, "must be a bounded object")
    end
  end
end
