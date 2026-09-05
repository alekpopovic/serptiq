# frozen_string_literal: true

module Crawling
  AdmissionPolicy = Data.define(:configuration, :policy_version, :source_version, :limits, :estimate) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end
  end
end
