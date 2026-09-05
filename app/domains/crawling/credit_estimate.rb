# frozen_string_literal: true

module Crawling
  CreditEstimate = Data.define(
    :http_pages, :rendered_pages, :http_weight, :rendered_weight, :maximum_credits,
    :catalog_version, :catalog_checksum, :meter_rates
  ) do
    def initialize(**attributes)
      attributes[:meter_rates] = attributes.fetch(:meter_rates).transform_values(&:freeze).freeze
      attributes[:catalog_checksum] = attributes.fetch(:catalog_checksum).to_s.dup.freeze
      super(**attributes)
      freeze
    end

    def rate_for(key)
      meter_rates.fetch(key.to_s)
    end
  end
end
