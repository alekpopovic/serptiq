# frozen_string_literal: true

module Entitlements
  class CatalogQuery
    def call
      Definition.order(:category, :key).map do |definition|
        DefinitionSummary.new(
          key: definition.key,
          value_type: definition.value_type,
          unit: definition.unit,
          category: definition.category,
          description: definition.customer_description
        )
      end.freeze
    end
  end
end
