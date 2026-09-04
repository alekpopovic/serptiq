# frozen_string_literal: true

module Entitlements
  class Definition < ApplicationRecord
    self.table_name = "entitlement_definitions"

    TYPES = %w[boolean integer decimal enum string].freeze
    KEY_PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/
    TAXONOMY_PATTERN = /\A[a-z][a-z0-9_]{1,31}\z/
    CHECKSUM_PATTERN = /\A[0-9a-f]{64}\z/

    has_many :plan_values, class_name: "Entitlements::PlanValue",
      foreign_key: :entitlement_definition_id, inverse_of: :definition,
      dependent: :restrict_with_exception
    has_many :organization_overrides, class_name: "Entitlements::OrganizationOverride",
      foreign_key: :entitlement_definition_id, inverse_of: :definition,
      dependent: :restrict_with_exception

    validates :key, format: { with: KEY_PATTERN }, uniqueness: true
    validates :value_type, inclusion: { in: TYPES }
    validates :unit, :category, format: { with: TAXONOMY_PATTERN }
    validates :customer_description, length: { in: 3..240 }, presence: true
    validates :catalog_checksum, format: { with: CHECKSUM_PATTERN }
    validate :stable_identity, on: :update
    before_destroy { throw(:abort) }

    def readonly?
      persisted? && !Entitlements.catalog_syncing?
    end

    private

    def stable_identity
      errors.add(:key, "is immutable") if will_save_change_to_key?
      errors.add(:value_type, "is immutable") if will_save_change_to_value_type?
    end
  end
end
