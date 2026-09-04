# frozen_string_literal: true

module Entitlements
  class SubscriptionContext < ApplicationRecord
    self.table_name = "entitlement_subscription_contexts"

    validates :organization_id, :subscription_id, :plan_version_id, presence: true
    validates :subscription_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :subscription_status, inclusion: {
      in: %w[pending incomplete trialing active past_due paused canceled expired]
    }
    validates :access_state, inclusion: { in: %w[pending full grace read_only suspended] }
    validates :organization_id, uniqueness: { conditions: -> { where(active: true) }, if: :active? }
    validates :subscription_id, uniqueness: true
    validate :identifier_shapes
    validate :access_timing_shape

    scope :active, -> { where(active: true) }

    private

    def identifier_shapes
      %i[organization_id subscription_id plan_version_id].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
    end

    def access_timing_shape
      valid = (subscription_status == "past_due") == grace_ends_at.present?
      valid &&= (subscription_status == "canceled") == access_expires_at.present?
      errors.add(:access_state, "does not match subscription timing") unless valid
    end
  end
end
