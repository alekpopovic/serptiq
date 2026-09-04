# frozen_string_literal: true

module Integrations
  module SearchConsole
    PROPERTY_PERMISSION_LEVELS = %w[siteOwner siteFullUser siteRestrictedUser siteUnverifiedUser].freeze

    PropertyAccess = Data.define(:external_property_identifier, :permission_level) do
      def initialize(external_property_identifier:, permission_level:)
        identifier = external_property_identifier.to_s
        permission = permission_level.to_s
        valid = identifier == identifier.strip && identifier.bytesize.between?(1, 2048) &&
          PROPERTY_PERMISSION_LEVELS.include?(permission)
        raise ArgumentError, "Search Console property access is invalid" unless valid

        super(external_property_identifier: identifier.freeze, permission_level: permission.freeze)
        freeze
      end

      def owner?
        permission_level == "siteOwner"
      end
    end
  end
end
