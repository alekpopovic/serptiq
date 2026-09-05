# frozen_string_literal: true

module Crawling
  UrlScopeDecision = Data.define(:allowed, :reason_code, :normalized_url) do
    def initialize(**attributes)
      attributes[:allowed] = attributes.fetch(:allowed) == true
      attributes[:reason_code] = attributes.fetch(:reason_code).to_s.freeze
      super(**attributes)
      freeze
    end

    def allowed?
      allowed
    end
  end
end
