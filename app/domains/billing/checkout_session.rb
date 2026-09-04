# frozen_string_literal: true

module Billing
  class CheckoutSession < ApplicationRecord
    self.table_name = "billing_checkout_sessions"

    STATES = %w[preparing ready uncertain failed expired].freeze
    ACTIVE_STATES = %w[preparing ready uncertain].freeze

    belongs_to :organization, class_name: "Tenancy::Organization"
    belongs_to :plan_version, class_name: "Plans::PlanVersion"
    belongs_to :actor_membership, class_name: "Tenancy::Membership"
    belongs_to :customer_mapping, class_name: "Billing::CustomerMapping",
      foreign_key: :billing_customer_id, optional: true

    validates :organization_id, :plan_version_id, :actor_membership_id, :expires_at, presence: true
    validates :provider, format: { with: ValueNormalization::PROVIDER_PATTERN }
    validates :environment, inclusion: { in: CustomerMapping::ENVIRONMENTS }
    validates :currency, format: { with: /\A[A-Z]{3}\z/ }
    validates :billing_interval, inclusion: { in: PlanProviderMapping::INTERVALS }
    validates :state, inclusion: { in: STATES }
    validates :idempotency_digest, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :provider_checkout_id, format: { with: ValueNormalization::REFERENCE_PATTERN }, allow_nil: true
    validates :failure_category, format: { with: ValueNormalization::KEY_PATTERN }, allow_nil: true
    validate :tenant_relationships
    validate :lifecycle_shape

    scope :active, -> { where(state: ACTIVE_STATES) }

    def inspect
      "#<#{self.class.name} id=#{id.inspect} organization_id=#{organization_id.inspect} " \
        "state=#{state.inspect} provider=#{provider.inspect} provider_checkout_id=[FILTERED] " \
        "idempotency_digest=[FILTERED]>"
    end

    private

    def tenant_relationships
      if actor_membership && actor_membership.organization_id != organization_id
        errors.add(:actor_membership_id, "must belong to the checkout organization")
      end
      if customer_mapping && (customer_mapping.organization_id != organization_id ||
          customer_mapping.provider != provider || customer_mapping.environment != environment)
        errors.add(:billing_customer_id, "must match the checkout tenant and provider")
      end
    end

    def lifecycle_shape
      valid = case state
      when "preparing"
        provider_checkout_id.nil? && ready_at.nil? && failed_at.nil? && failure_category.nil?
      when "ready"
        billing_customer_id.present? && provider_checkout_id.present? && ready_at.present? &&
          failed_at.nil? && failure_category.nil?
      when "uncertain", "failed"
        provider_checkout_id.nil? && ready_at.nil? && failed_at.present? && failure_category.present?
      when "expired"
        true
      else
        false
      end
      valid &&= created_at.nil? || expires_at > created_at
      errors.add(:state, "does not match checkout lifecycle") unless valid
    end
  end
end
