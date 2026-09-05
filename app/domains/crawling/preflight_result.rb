# frozen_string_literal: true

module Crawling
  PreflightResult = Data.define(:checked_at, :status_code, :destination_digest, :redirect_count) do
    def initialize(**attributes)
      attributes[:status_code] = Integer(attributes.fetch(:status_code))
      attributes[:redirect_count] = Integer(attributes.fetch(:redirect_count))
      super(**attributes)
      freeze
    end
  end
end
