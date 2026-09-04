# frozen_string_literal: true

module Verification
  SearchConsoleSelection = Data.define(
    :connection_id, :external_property_identifier, :property_type,
    :permission_level, :checked_at, :connection_revision
  ) do
    def initialize(**attributes)
      %i[connection_id external_property_identifier property_type permission_level].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      attributes[:connection_revision] = Integer(attributes.fetch(:connection_revision))
      super(**attributes)
      freeze
    end

    def provider_observation
      ProviderObservation.new(
        external_property_identifier: external_property_identifier,
        permission_level: permission_level,
        checked_at: checked_at
      )
    end
  end
end
