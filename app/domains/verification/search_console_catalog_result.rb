# frozen_string_literal: true

module Verification
  SearchConsoleCatalogResult = Data.define(:status, :options) do
    def initialize(status:, options: [])
      normalized = status.to_s
      allowed = %w[available no_connection no_match insufficient_permission ambiguous provider_unavailable]
      raise ArgumentError, "Search Console catalog status is invalid" unless allowed.include?(normalized)

      super(status: normalized.freeze, options: Array(options).freeze)
      freeze
    end

    def available?
      status == "available"
    end

    def message
      {
        "available" => "Select the exact provider property that Google reports as verified owner access.",
        "no_connection" => "No separately authorized Search Console connection is available.",
        "no_match" => "No accessible Search Console property exactly covers this origin.",
        "insufficient_permission" => "A matching property exists, but Google does not report verified owner permission.",
        "ambiguous" => "Google returned an ambiguous duplicate match; reauthorize before selecting a property.",
        "provider_unavailable" => "Search Console properties could not be checked right now. Try again later."
      }.fetch(status)
    end
  end
end
