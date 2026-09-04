# frozen_string_literal: true

module Usage
  class UsageWindow < ApplicationRecord
    self.table_name = "usage_windows"

    belongs_to :meter_definition, class_name: "Usage::MeterDefinition",
      foreign_key: :usage_meter_definition_id
    has_many :events, class_name: "Usage::UsageEvent", foreign_key: :usage_window_id,
      dependent: :restrict_with_exception

    validates :organization_id, :usage_meter_definition_id, :starts_at, :ends_at,
      :window_policy, :time_zone_name, :created_at, presence: true
    validates :window_policy, inclusion: { in: Catalog::WINDOW_POLICIES }
    validates :time_zone_name, length: { maximum: 64 }
    validates :period_reference_digest, format: { with: /\A[0-9a-f]{64}\z/ }, allow_nil: true
    validate :identifier_shapes
    validate :period_shape
    validate :subscription_context_shape

    scope :covering, ->(at) { where("starts_at <= ? AND ends_at > ?", at, at) }

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "usage windows are immutable"
    end

    private

    def identifier_shapes
      %i[organization_id usage_meter_definition_id].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
    end

    def period_shape
      errors.add(:ends_at, "must follow the start") unless starts_at && ends_at && ends_at > starts_at
      valid = if window_policy == "utc_calendar_month"
        time_zone_name == "UTC" && period_reference_digest.nil?
      else
        period_reference_digest.present? && valid_time_zone?
      end
      errors.add(:window_policy, "does not match period metadata") unless valid
    end

    def subscription_context_shape
      values = [ subscription_id, plan_version_id, subscription_revision ]
      valid = values.all?(&:nil?) || (
        Shared::Public.application_uuid?(subscription_id) &&
        Shared::Public.application_uuid?(plan_version_id) &&
        subscription_revision.is_a?(Integer) && subscription_revision >= 0
      )
      errors.add(:subscription_id, "has incomplete context") unless valid
    end

    def valid_time_zone?
      ActiveSupport::TimeZone[time_zone_name] || ActiveSupport::TimeZone.all.any? do |zone|
        zone.tzinfo.name == time_zone_name
      end
    end
  end
end
