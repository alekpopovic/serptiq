# frozen_string_literal: true

module Entitlements
  DefinitionSummary = Data.define(:key, :value_type, :unit, :category, :description) do
    def initialize(**attributes)
      attributes.transform_values! { |value| value.to_s.freeze }
      super(**attributes)
      freeze
    end

    def display(value)
      return "Unavailable" if value.nil?
      return "Contract configuration required" if value == "custom"
      return value ? "Enabled" : "Disabled" if value_type == "boolean"
      return "Disabled" if value == 0 || value == "none" || value == "disabled"
      return "#{value.to_fs(:delimited)} #{unit.humanize.downcase}" if value.is_a?(Numeric)

      value.to_s.humanize
    end

    def state(value)
      return "unavailable" if value.nil?
      return "custom" if value == "custom"
      return "disabled" if value == false || value == 0 || %w[none disabled].include?(value)

      "enabled"
    end
  end
end
