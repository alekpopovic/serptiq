# frozen_string_literal: true

module Crawling
  CreditEstimate = Data.define(
    :http_pages, :rendered_pages, :http_weight, :rendered_weight, :maximum_credits
  ) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end
  end
end
