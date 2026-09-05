# frozen_string_literal: true

module Crawling
  ConcurrentScanLimits = Data.define(:organization, :project, :global, :provenance) do
    def initialize(**attributes)
      %i[organization project global].each { |name| attributes[name] = Integer(attributes.fetch(name)) }
      attributes[:provenance] = attributes.fetch(:provenance).to_s.freeze
      super(**attributes)
      freeze
    end
  end
end
