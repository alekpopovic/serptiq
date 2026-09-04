# frozen_string_literal: true

module Entitlements
  CatalogSyncResult = Data.define(:definition_count, :plan_value_count, :changes, :dry_run, :checksum) do
    def initialize(**attributes)
      attributes[:changes] = Array(attributes.fetch(:changes)).map { |value| value.to_s.freeze }.freeze
      attributes[:checksum] = attributes.fetch(:checksum).to_s.freeze
      super(**attributes)
      freeze
    end

    def dry_run?
      dry_run
    end

    def change_count
      changes.length
    end
  end
end
