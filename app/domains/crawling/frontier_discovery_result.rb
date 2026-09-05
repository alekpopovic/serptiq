# frozen_string_literal: true

module Crawling
  FrontierDiscoveryResult = Data.define(:scan_id, :inserted_count, :items) do
    def initialize(**attributes)
      attributes[:scan_id] = attributes.fetch(:scan_id).to_s.freeze
      attributes[:inserted_count] = Integer(attributes.fetch(:inserted_count))
      attributes[:items] = Array(attributes.fetch(:items)).freeze
      super(**attributes)
      freeze
    end
  end
end
