# frozen_string_literal: true

module Usage
  class MeterRate < ApplicationRecord
    self.table_name = "usage_meter_rates"

    belongs_to :definition, class_name: "Usage::MeterDefinition",
      foreign_key: :usage_meter_definition_id, inverse_of: :rates

    validates :version, numericality: { only_integer: true, greater_than: 0 }
    validates :weight, numericality: { greater_than: 0 }
    validates :effective_at, presence: true
    validates :catalog_checksum, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :version, :effective_at, uniqueness: { scope: :usage_meter_definition_id }

    scope :effective_at, ->(at) { where(effective_at: ..at).order(effective_at: :desc, version: :desc) }

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "usage meter rates are immutable"
    end
  end
end
