# frozen_string_literal: true

module Verification
  class SearchConsoleSelectionError < ArgumentError
    attr_reader :failure_category, :observation

    def initialize(failure_category, observation: nil)
      category = failure_category.to_s
      raise ArgumentError, "Search Console failure category is invalid" unless
        SearchConsoleFailureMessage::MESSAGES.key?(category)

      @failure_category = category.freeze
      @observation = observation
      super(SearchConsoleFailureMessage.for(category))
    end
  end
end
