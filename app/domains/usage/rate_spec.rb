# frozen_string_literal: true

module Usage
  RateSpec = Data.define(:version, :weight, :effective_at, :catalog_checksum) do
    def initialize(**attributes)
      attributes[:catalog_checksum] = attributes.fetch(:catalog_checksum).to_s.dup.freeze
      super(**attributes)
      freeze
    end

    def attributes_for(meter_definition_id:)
      to_h.merge(usage_meter_definition_id: meter_definition_id)
    end
  end
end
