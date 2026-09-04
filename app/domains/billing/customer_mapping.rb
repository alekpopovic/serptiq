# frozen_string_literal: true

module Billing
  class CustomerMapping < ApplicationRecord
    self.table_name = "billing_customers"

    ENVIRONMENTS = PlanProviderMapping::ENVIRONMENTS
    PROVIDER_PATTERN = ValueNormalization::PROVIDER_PATTERN
    REFERENCE_PATTERN = ValueNormalization::REFERENCE_PATTERN

    has_many :subscriptions, class_name: "Billing::Subscription", foreign_key: :billing_customer_id,
      dependent: :restrict_with_exception

    validates :organization_id, :provider_customer_id, presence: true
    validates :provider, format: { with: PROVIDER_PATTERN }
    validates :environment, inclusion: { in: ENVIRONMENTS }
    validates :provider_customer_id, format: { with: REFERENCE_PATTERN }
    validates :organization_id, uniqueness: { scope: %i[provider environment] }
    validates :provider_customer_id, uniqueness: { scope: %i[provider environment] }
    validate :identifier_shape

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "billing customer mappings are immutable"
    end

    private

    def identifier_shape
      errors.add(:organization_id, "is invalid") unless Shared::Public.application_uuid?(organization_id)
    end
  end
end
