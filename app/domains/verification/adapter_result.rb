# frozen_string_literal: true

module Verification
  AdapterResult = Data.define(:verified, :failure_category, :evidence, :provider_observation) do
    def initialize(verified:, failure_category: nil, evidence: {}, provider_observation: nil)
      success = !!verified
      category = failure_category&.to_s
      if success
        raise ArgumentError, "verified result cannot have a failure category" if category
      elsif !Challenge::FAILURE_CATEGORIES.include?(category)
        raise ArgumentError, "adapter failure category is invalid"
      end
      unless provider_observation.nil? || provider_observation.is_a?(ProviderObservation)
        raise ArgumentError, "provider observation is invalid"
      end
      super(
        verified: success,
        failure_category: category&.freeze,
        evidence: Evidence.sanitize(evidence),
        provider_observation: provider_observation
      )
      freeze
    end

    def verified?
      verified
    end
  end
end
