# frozen_string_literal: true

module Properties
  module Public
    PropertyReference = Data.define(
      :id, :organization_id, :project_id, :kind, :status, :verification_status, :configuration
    ) do
      def initialize(**attributes)
        %i[id organization_id project_id kind status verification_status].each do |name|
          attributes[name] = attributes.fetch(name).to_s.freeze
        end
        super(**attributes)
        freeze
      end

      def active?
        status == "active"
      end

      def verified?
        verification_status == "verified"
      end

      def scan_available?
        active? && verified?
      end
    end
  end
end
