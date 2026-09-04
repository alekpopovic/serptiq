# frozen_string_literal: true

module Billing
  class Subscription < ApplicationRecord
    self.table_name = "subscriptions"

    STATUSES = %w[active inactive].freeze
    BILLING_INTERVALS = %w[monthly annual custom].freeze
    PRICING_KINDS = %w[fixed custom].freeze

    validates :organization_id, :plan_version_id, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :billing_interval, inclusion: { in: BILLING_INTERVALS }
    validates :plan_key_snapshot, presence: true, length: { maximum: 32 }
    validates :plan_version_snapshot, numericality: { only_integer: true, greater_than: 0 }
    validates :plan_display_name_snapshot, presence: true, length: { maximum: 80 }
    validates :currency_snapshot, format: { with: /\A[A-Z]{3}\z/ }
    validates :pricing_kind_snapshot, inclusion: { in: PRICING_KINDS }
    validates :organization_id, uniqueness: {
      conditions: -> { where(status: "active") },
      if: -> { status == "active" }
    }
    validate :identifier_shape
    validate :price_shape
    validate :lifecycle_shape

    private

    def identifier_shape
      errors.add(:organization_id, "is invalid") unless Shared::Public.application_uuid?(organization_id)
      errors.add(:plan_version_id, "is invalid") unless Shared::Public.application_uuid?(plan_version_id)
    end

    def price_shape
      valid = if pricing_kind_snapshot == "fixed"
        %w[monthly annual].include?(billing_interval) && price_cents_snapshot.is_a?(Integer) &&
          price_cents_snapshot >= 0
      else
        billing_interval == "custom" && price_cents_snapshot.nil?
      end
      errors.add(:pricing_kind_snapshot, "does not match the billing interval and price") unless valid
    end

    def lifecycle_shape
      valid = status == "active" ? ended_at.nil? : ended_at.present?
      errors.add(:status, "does not match lifecycle timestamps") unless valid
    end
  end
end
