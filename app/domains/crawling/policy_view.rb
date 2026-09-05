# frozen_string_literal: true

module Crawling
  PolicyView = Data.define(:configuration, :version, :limits, :estimate, :persisted) do
    def initialize(**attributes)
      attributes[:version] = Integer(attributes.fetch(:version))
      attributes[:persisted] = !!attributes.fetch(:persisted)
      super(**attributes)
      freeze
    end

    def persisted?
      persisted
    end
  end
end
