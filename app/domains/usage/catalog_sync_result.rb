# frozen_string_literal: true

module Usage
  CatalogSyncResult = Data.define(:meter_count, :rate_count, :changes, :dry_run, :checksum) do
    def initialize(**attributes)
      attributes[:changes] = Array(attributes.fetch(:changes)).map { |value| value.to_s.freeze }.freeze
      attributes[:checksum] = attributes.fetch(:checksum).to_s.freeze
      super(**attributes)
      freeze
    end

    def change_count
      changes.length
    end

    def dry_run?
      dry_run
    end
  end
end
