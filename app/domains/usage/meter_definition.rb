# frozen_string_literal: true

module Usage
  class MeterDefinition < ApplicationRecord
    self.table_name = "usage_meter_definitions"

    has_many :rates, class_name: "Usage::MeterRate", foreign_key: :usage_meter_definition_id,
      inverse_of: :definition, dependent: :restrict_with_exception

    validates :key, :pool_key, format: { with: Catalog::KEY_PATTERN }, length: { maximum: 96 }
    validates :unit, :billing_unit, format: { with: Catalog::UNIT_PATTERN }
    validates :window_policy, inclusion: { in: Catalog::WINDOW_POLICIES }
    validates :name, presence: true, length: { maximum: 100 }
    validates :description, presence: true, length: { maximum: 240 }
    validates :catalog_checksum, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :key, uniqueness: true
    validate :quota_entitlement_key_shape

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "usage meter definitions are immutable"
    end

    private

    def quota_entitlement_key_shape
      return if quota_entitlement_key.nil? || Catalog::KEY_PATTERN.match?(quota_entitlement_key)

      errors.add(:quota_entitlement_key, "is invalid")
    end
  end
end
