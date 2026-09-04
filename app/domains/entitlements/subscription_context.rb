# frozen_string_literal: true

module Entitlements
  class SubscriptionContext < ApplicationRecord
    self.table_name = "entitlement_subscription_contexts"

    validates :organization_id, :subscription_id, :plan_version_id, presence: true
    validates :subscription_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :organization_id, uniqueness: { conditions: -> { where(active: true) }, if: :active? }
    validates :subscription_id, uniqueness: true
    validate :identifier_shapes

    scope :active, -> { where(active: true) }

    private

    def identifier_shapes
      %i[organization_id subscription_id plan_version_id].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
    end
  end
end
