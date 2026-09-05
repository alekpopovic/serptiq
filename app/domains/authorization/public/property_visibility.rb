# frozen_string_literal: true

module Authorization
  module Public
    PropertyVisibility = Data.define(:all_properties, :property_ids) do
      def initialize(all_properties:, property_ids: [])
        super(
          all_properties: !!all_properties,
          property_ids: property_ids.map { |id| id.to_s.freeze }.uniq.freeze
        )
        freeze
      end

      def all_properties?
        all_properties
      end

      def accessible?
        all_properties? || property_ids.any?
      end
    end
  end
end
