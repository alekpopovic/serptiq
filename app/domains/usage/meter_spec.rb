# frozen_string_literal: true

module Usage
  MeterSpec = Data.define(
    :key, :name, :unit, :billing_unit, :pool_key, :quota_entitlement_key,
    :window_policy, :description, :catalog_checksum, :rates
  ) do
    def initialize(**attributes)
      %i[key name unit billing_unit pool_key quota_entitlement_key window_policy description catalog_checksum].each do |name|
        attributes[name] = attributes[name]&.to_s&.dup&.freeze
      end
      attributes[:rates] = Array(attributes.fetch(:rates)).freeze
      super(**attributes)
      freeze
    end

    def definition_attributes
      to_h.except(:rates)
    end
  end
end
