# frozen_string_literal: true

module Billing
  class Subscription < ApplicationRecord
    self.table_name = "subscriptions"

    STATUSES = SubscriptionLifecycle::STATUSES
    ACCESS_STATES = SubscriptionLifecycle::ACCESS_STATES
    BILLING_INTERVALS = %w[monthly annual custom].freeze
    PRICING_KINDS = %w[fixed custom].freeze

    belongs_to :customer_mapping, class_name: "Billing::CustomerMapping",
      foreign_key: :billing_customer_id, optional: true

    validates :organization_id, :plan_version_id, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :access_state, inclusion: { in: ACCESS_STATES }
    validates :billing_interval, inclusion: { in: BILLING_INTERVALS }
    validates :plan_key_snapshot, presence: true, length: { maximum: 32 }
    validates :plan_version_snapshot, numericality: { only_integer: true, greater_than: 0 }
    validates :plan_display_name_snapshot, presence: true, length: { maximum: 80 }
    validates :currency_snapshot, format: { with: /\A[A-Z]{3}\z/ }
    validates :pricing_kind_snapshot, inclusion: { in: PRICING_KINDS }
    validates :organization_id, uniqueness: {
      conditions: -> { where(ended_at: nil) },
      if: -> { ended_at.nil? }
    }
    validate :identifier_shape
    validate :price_shape
    validate :lifecycle_shape
    validate :provider_shape
    validate :provider_metadata_shape
    validate :period_shape
    validate :cancellation_shape

    scope :current, -> { where(ended_at: nil) }

    def current?
      ended_at.nil?
    end

    def provider_backed?
      provider.present?
    end

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
      valid = SubscriptionLifecycle.valid?(status: status, access_state: access_state) &&
        ((status == "expired") == ended_at.present?)
      errors.add(:status, "does not match lifecycle timestamps") unless valid
    end

    def provider_shape
      provider_fields = [
        billing_customer_id, provider, provider_environment, provider_subscription_id,
        provider_updated_at, last_synced_at
      ]
      valid = if provider_fields.all?(&:nil?)
        provider_metadata == {}
      else
        provider_fields.none?(&:nil?) && ValueNormalization::PROVIDER_PATTERN.match?(provider.to_s) &&
          CustomerMapping::ENVIRONMENTS.include?(provider_environment) &&
          ValueNormalization::REFERENCE_PATTERN.match?(provider_subscription_id.to_s) &&
          provider_metadata.is_a?(Hash) && provider_metadata.key?("raw_status")
      end
      errors.add(:provider, "has incomplete provider context") unless valid
    end

    def provider_metadata_shape
      ValueNormalization.metadata(provider_metadata)
    rescue ArgumentError
      errors.add(:provider_metadata, "is invalid")
    end

    def period_shape
      valid = if current_period_starts_at.nil? && current_period_ends_at.nil?
        true
      else
        current_period_starts_at && current_period_ends_at &&
          current_period_ends_at > current_period_starts_at
      end
      valid &&= trial_ends_at.nil? || trial_ends_at >= started_at
      valid &&= last_synced_at.nil? || provider_updated_at.nil? || last_synced_at >= provider_updated_at
      errors.add(:current_period_ends_at, "has invalid provider timing") unless valid
    end

    def cancellation_shape
      valid = if cancel_at_period_end || status == "canceled"
        canceled_at.present?
      elsif status == "expired"
        true
      else
        canceled_at.nil?
      end
      errors.add(:canceled_at, "does not match cancellation state") unless valid
    end
  end
end
