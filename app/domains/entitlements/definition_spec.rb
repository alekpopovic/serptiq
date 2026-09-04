# frozen_string_literal: true

module Entitlements
  DefinitionSpec = Data.define(
    :key, :value_type, :unit, :category, :minimum_value, :maximum_value,
    :allowed_values, :max_length, :allow_custom, :security_sensitive,
    :system_default, :customer_description, :catalog_checksum
  ) do
    def initialize(**attributes)
      attributes[:key] = attributes.fetch(:key).to_s.freeze
      attributes[:value_type] = attributes.fetch(:value_type).to_s.freeze
      attributes[:unit] = attributes.fetch(:unit).to_s.freeze
      attributes[:category] = attributes.fetch(:category).to_s.freeze
      attributes[:allowed_values] = Array(attributes.fetch(:allowed_values)).map { |value| value.to_s.freeze }.freeze
      attributes[:customer_description] = attributes.fetch(:customer_description).to_s.freeze
      attributes[:catalog_checksum] = attributes.fetch(:catalog_checksum).to_s.freeze
      attributes[:allow_custom] = !!attributes.fetch(:allow_custom)
      attributes[:security_sensitive] = !!attributes.fetch(:security_sensitive)
      super(**attributes)
      freeze
    end

    def definition_attributes
      to_h.except(:key).merge(key: key)
    end
  end
end
