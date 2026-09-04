# frozen_string_literal: true

module Usage
  class UsageEvent < ApplicationRecord
    self.table_name = "usage_events"
    self.record_timestamps = false

    KINDS = %w[usage correction manual_adjustment].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/
    REASON_PATTERN = /\A[a-z][a-z0-9_]{1,63}\z/

    belongs_to :window, class_name: "Usage::UsageWindow", foreign_key: :usage_window_id
    belongs_to :meter_definition, class_name: "Usage::MeterDefinition",
      foreign_key: :usage_meter_definition_id
    belongs_to :meter_rate, class_name: "Usage::MeterRate", foreign_key: :usage_meter_rate_id
    belongs_to :correction_of, class_name: "Usage::UsageEvent",
      foreign_key: :correction_of_event_id, optional: true

    validates :organization_id, :source_organization_id, :usage_window_id,
      :usage_meter_definition_id, :usage_meter_rate_id, :source_id, presence: true
    validates :idempotency_key_digest, :request_checksum, format: { with: DIGEST_PATTERN }
    validates :event_kind, inclusion: { in: KINDS }
    validates :quantity, numericality: { other_than: 0 }
    validates :applied_weight, numericality: { greater_than: 0 }
    validates :billed_quantity, numericality: true
    validates :source_type, format: { with: SourceReference::TYPE_PATTERN }
    validates :reason_code, format: { with: REASON_PATTERN }, allow_nil: true
    validates :occurred_at, :recorded_at, presence: true
    validate :tenant_and_identifier_shapes
    validate :kind_shape
    validate :weighted_quantity
    validate :metadata_shape
    validate :recording_order

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "usage events are append-only"
    end

    private

    def tenant_and_identifier_shapes
      identifiers = %i[
        organization_id source_organization_id usage_window_id usage_meter_definition_id
        usage_meter_rate_id source_id
      ]
      identifiers << :actor_membership_id if actor_membership_id
      identifiers.each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
      errors.add(:source_organization_id, "must match organization") unless
        organization_id.to_s == source_organization_id.to_s
    end

    def kind_shape
      valid = case event_kind
      when "usage"
        quantity&.positive? && correction_of_event_id.nil? && actor_membership_id.nil? && reason_code.nil?
      when "correction"
        correction_of_event_id.present? && reason_code.present?
      when "manual_adjustment"
        correction_of_event_id.nil? && actor_membership_id.present? && reason_code.present?
      else
        false
      end
      errors.add(:event_kind, "does not match event metadata") unless valid
    end

    def weighted_quantity
      return if quantity && applied_weight && billed_quantity == quantity * applied_weight

      errors.add(:billed_quantity, "does not match quantity and applied weight")
    end

    def metadata_shape
      valid = metadata.is_a?(Hash) && JSON.generate(metadata).bytesize <= 2.kilobytes
      errors.add(:metadata, "must be a bounded object") unless valid
    rescue JSON::GeneratorError
      errors.add(:metadata, "must be a bounded object")
    end

    def recording_order
      return if occurred_at && recorded_at && recorded_at >= occurred_at

      errors.add(:recorded_at, "must not precede occurrence")
    end
  end
end
