# frozen_string_literal: true

module Verification
  AdapterResult = Data.define(:verified, :failure_category, :evidence) do
    def initialize(verified:, failure_category: nil, evidence: {})
      success = !!verified
      category = failure_category&.to_s
      if success
        raise ArgumentError, "verified result cannot have a failure category" if category
      elsif !Challenge::FAILURE_CATEGORIES.include?(category)
        raise ArgumentError, "adapter failure category is invalid"
      end
      super(verified: success, failure_category: category&.freeze, evidence: Evidence.sanitize(evidence))
      freeze
    end

    def verified?
      verified
    end
  end
end
