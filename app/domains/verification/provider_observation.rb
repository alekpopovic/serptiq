# frozen_string_literal: true

module Verification
  ProviderObservation = Data.define(:external_property_identifier, :permission_level, :checked_at) do
    def initialize(external_property_identifier:, permission_level:, checked_at:)
      identifier = external_property_identifier.to_s
      permission = permission_level.to_s
      valid_time = checked_at.is_a?(Time) || checked_at.is_a?(ActiveSupport::TimeWithZone)
      valid = identifier.bytesize.between?(1, 2048) &&
        Integrations::Public::SEARCH_CONSOLE_PERMISSION_LEVELS.include?(permission) && valid_time
      raise ArgumentError, "provider observation is invalid" unless valid

      super(
        external_property_identifier: identifier.freeze,
        permission_level: permission.freeze,
        checked_at: checked_at
      )
      freeze
    end
  end
end
