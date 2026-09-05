# frozen_string_literal: true

module Usage
  class QuotaAllocation < ApplicationRecord
    self.table_name = "usage_quota_allocations"

    STATES = %w[held consumed released].freeze

    belongs_to :reservation, class_name: "Usage::QuotaReservation",
      foreign_key: :usage_quota_reservation_id, inverse_of: :allocations
    belongs_to :window, class_name: "Usage::UsageWindow", foreign_key: :usage_window_id
    belongs_to :meter_definition, class_name: "Usage::MeterDefinition",
      foreign_key: :usage_meter_definition_id
    belongs_to :meter_rate, class_name: "Usage::MeterRate", foreign_key: :usage_meter_rate_id
    belongs_to :usage_event, class_name: "Usage::UsageEvent", optional: true

    validates :organization_id, :usage_quota_reservation_id, :usage_window_id,
      :usage_meter_definition_id, :usage_meter_rate_id, :source_id, :allocated_at, presence: true
    validates :idempotency_key_digest, :request_checksum, format: { with: UsageEvent::DIGEST_PATTERN }
    validates :completion_key_digest, :completion_checksum,
      format: { with: UsageEvent::DIGEST_PATTERN }, allow_nil: true
    validates :state, inclusion: { in: STATES }
    validates :quantity, :applied_weight, :billed_quantity, numericality: { greater_than: 0 }
    validates :source_type, format: { with: SourceReference::TYPE_PATTERN }
    validate :identifier_shapes
    validate :weighted_quantity
    validate :lifecycle_shape

    scope :held, -> { where(state: "held") }

    def held?
      state == "held"
    end

    def consumed?
      state == "consumed"
    end

    def released?
      state == "released"
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "usage quota allocations cannot be deleted"
    end

    private

    def identifier_shapes
      %i[
        organization_id usage_quota_reservation_id usage_window_id
        usage_meter_definition_id usage_meter_rate_id source_id
      ].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
    end

    def weighted_quantity
      return if quantity && applied_weight && billed_quantity == quantity * applied_weight

      errors.add(:billed_quantity, "does not match quantity and applied weight")
    end

    def lifecycle_shape
      valid = case state
      when "held"
        completion_key_digest.nil? && completion_checksum.nil? && usage_event_id.nil? && completed_at.nil?
      when "consumed"
        completion_key_digest.present? && completion_checksum.present? &&
          usage_event_id.present? && completed_at.present?
      when "released"
        completion_key_digest.present? && completion_checksum.present? &&
          usage_event_id.nil? && completed_at.present?
      else
        false
      end
      errors.add(:state, "does not match allocation lifecycle") unless valid
    end
  end
end
