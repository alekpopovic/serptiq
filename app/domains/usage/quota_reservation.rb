# frozen_string_literal: true

module Usage
  class QuotaReservation < ApplicationRecord
    self.table_name = "usage_quota_reservations"

    STATES = %w[held finalized released expired].freeze
    LIMIT_KINDS = %w[capped unlimited].freeze

    belongs_to :window, class_name: "Usage::UsageWindow", foreign_key: :usage_window_id
    belongs_to :meter_definition, class_name: "Usage::MeterDefinition",
      foreign_key: :usage_meter_definition_id
    belongs_to :meter_rate, class_name: "Usage::MeterRate", foreign_key: :usage_meter_rate_id
    belongs_to :finalized_usage_event, class_name: "Usage::UsageEvent", optional: true
    has_many :operations, class_name: "Usage::ReservationOperation",
      foreign_key: :usage_quota_reservation_id, dependent: :restrict_with_exception
    has_many :allocations, class_name: "Usage::QuotaAllocation",
      foreign_key: :usage_quota_reservation_id, inverse_of: :reservation,
      dependent: :restrict_with_exception

    validates :organization_id, :source_organization_id, :usage_window_id,
      :usage_meter_definition_id, :usage_meter_rate_id, :source_id, presence: true
    validates :idempotency_key_digest, :request_checksum,
      format: { with: UsageEvent::DIGEST_PATTERN }
    validates :state, inclusion: { in: STATES }
    validates :limit_kind, inclusion: { in: LIMIT_KINDS }
    validates :requested_quantity, :held_quantity, numericality: { greater_than: 0 }
    validates :consumed_quantity, :released_quantity,
      numericality: { greater_than_or_equal_to: 0 }
    validates :source_type, format: { with: SourceReference::TYPE_PATTERN }
    validates :entitlement_provenance, format: { with: /\A[a-z][a-z0-9_]{1,31}\z/ }
    validates :admitted_at, :expires_at, presence: true
    validate :tenant_and_identifier_shapes
    validate :limit_snapshot_shape
    validate :subscription_snapshot_shape
    validate :lifecycle_shape

    scope :active_at, ->(at) { where(state: "held").where("expires_at > ?", at) }
    scope :stale_at, ->(at) { where(state: "held", expires_at: ..at) }

    def held?
      state == "held"
    end

    def finalized?
      state == "finalized"
    end

    def released?
      state == "released"
    end

    def expired?
      state == "expired"
    end

    def unlimited?
      limit_kind == "unlimited"
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "usage quota reservations cannot be deleted"
    end

    private

    def tenant_and_identifier_shapes
      identifiers = %i[
        organization_id source_organization_id usage_window_id usage_meter_definition_id
        usage_meter_rate_id source_id
      ]
      identifiers.concat(%i[entitlement_override_id subscription_id plan_version_id].select { |name| public_send(name) })
      identifiers.each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
      errors.add(:source_organization_id, "must match organization") unless
        source_organization_id.to_s == organization_id.to_s
    end

    def limit_snapshot_shape
      valid = if unlimited?
        limit_quantity.nil? && entitlement_key.nil? && entitlement_state == "unlimited" &&
          entitlement_definition_checksum.nil?
      else
        limit_quantity && limit_quantity >= 0 && Catalog::KEY_PATTERN.match?(entitlement_key.to_s) &&
          %w[enabled disabled].include?(entitlement_state) &&
          UsageEvent::DIGEST_PATTERN.match?(entitlement_definition_checksum.to_s)
      end
      errors.add(:limit_kind, "has an invalid snapshot") unless valid
    end

    def subscription_snapshot_shape
      valid = if subscription_id.nil?
        subscription_revision.nil?
      else
        plan_version_id.present? && subscription_revision.is_a?(Integer) && subscription_revision >= 0
      end
      errors.add(:subscription_id, "has incomplete context") unless valid
    end

    def lifecycle_shape
      valid = requested_quantity == held_quantity && expires_at && admitted_at && expires_at > admitted_at
      valid &&= case state
      when "held"
        consumed_quantity && consumed_quantity >= 0 && consumed_quantity <= held_quantity &&
          released_quantity&.zero? && finalized_usage_event_id.nil? &&
          finalized_at.nil? && released_at.nil? && expired_at.nil?
      when "finalized"
        consumed_quantity && released_quantity && consumed_quantity + released_quantity == held_quantity &&
          finalized_at.present? && released_at.nil? && expired_at.nil?
      when "released"
        consumed_quantity&.zero? && released_quantity == held_quantity &&
          finalized_usage_event_id.nil? && finalized_at.nil? && released_at.present? && expired_at.nil?
      when "expired"
        consumed_quantity && released_quantity && consumed_quantity + released_quantity == held_quantity &&
          finalized_usage_event_id.nil? && finalized_at.nil? && released_at.nil? && expired_at.present?
      else
        false
      end
      errors.add(:state, "does not match lifecycle quantities") unless valid
    end
  end
end
