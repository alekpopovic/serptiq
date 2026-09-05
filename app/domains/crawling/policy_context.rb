# frozen_string_literal: true

module Crawling
  PolicyContext = Data.define(:project, :property, :environment, :authorization) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end
  end
end
