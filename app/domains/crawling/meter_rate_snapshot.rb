# frozen_string_literal: true

module Crawling
  MeterRateSnapshot = Data.define(
    :key, :definition_checksum, :version, :weight, :effective_at, :rate_checksum
  ) do
    def initialize(**attributes)
      attributes[:key] = attributes.fetch(:key).to_s.dup.freeze
      attributes[:definition_checksum] = attributes.fetch(:definition_checksum).to_s.dup.freeze
      attributes[:rate_checksum] = attributes.fetch(:rate_checksum).to_s.dup.freeze
      super(**attributes)
      freeze
    end

    def as_json(*)
      {
        "key" => key,
        "definition_checksum" => definition_checksum,
        "version" => version,
        "weight" => weight.to_s("F"),
        "effective_at" => effective_at.utc.iso8601(6),
        "rate_checksum" => rate_checksum
      }
    end
  end
end
