# frozen_string_literal: true

module Crawling
  PolicyView = Data.define(
    :configuration, :version, :limits, :estimate, :persisted, :robots_override_available
  ) do
    def initialize(**attributes)
      attributes[:version] = Integer(attributes.fetch(:version))
      attributes[:persisted] = !!attributes.fetch(:persisted)
      attributes[:robots_override_available] = !!attributes.fetch(:robots_override_available)
      super(**attributes)
      freeze
    end

    def persisted?
      persisted
    end

    def robots_override_available?
      robots_override_available
    end
  end
end
