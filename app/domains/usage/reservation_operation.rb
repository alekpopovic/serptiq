# frozen_string_literal: true

module Usage
  class ReservationOperation < ApplicationRecord
    self.table_name = "usage_quota_reservation_operations"
    self.record_timestamps = false

    KINDS = %w[extend finalize release expire].freeze

    belongs_to :reservation, class_name: "Usage::QuotaReservation",
      foreign_key: :usage_quota_reservation_id, inverse_of: :operations
    belongs_to :usage_event, class_name: "Usage::UsageEvent", optional: true

    validates :organization_id, :usage_quota_reservation_id, :created_at, presence: true
    validates :operation_kind, inclusion: { in: KINDS }
    validates :idempotency_key_digest, :request_checksum,
      format: { with: UsageEvent::DIGEST_PATTERN }
    validates :quantity, numericality: { greater_than_or_equal_to: 0 }
    validate :identifier_shapes
    validate :event_shape

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "usage quota reservation operations are append-only"
    end

    private

    def identifier_shapes
      %i[organization_id usage_quota_reservation_id].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
    end

    def event_shape
      errors.add(:usage_event_id, "is only valid for finalization") if
        usage_event_id.present? && operation_kind != "finalize"
    end
  end
end
