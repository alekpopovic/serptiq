# frozen_string_literal: true

module Properties
  module Public
    EnvironmentReference = Data.define(
      :id, :organization_id, :project_id, :property_id, :key, :kind, :status, :primary, :origin
    ) do
      def initialize(**attributes)
        %i[id organization_id project_id property_id key kind status].each do |name|
          attributes[name] = attributes.fetch(name).to_s.freeze
        end
        attributes[:primary] = !!attributes.fetch(:primary)
        super(**attributes)
        freeze
      end

      def active?
        status == "active"
      end

      def primary?
        primary
      end
    end
  end
end
