# frozen_string_literal: true

module Crawling
  SitemapWarning = Data.define(:code, :entry_index) do
    def initialize(code:, entry_index: nil)
      normalized_code = code.to_s
      normalized_index = entry_index.nil? ? nil : Integer(entry_index)
      raise ArgumentError, "sitemap warning is invalid" unless
        SitemapWarning::CODE_PATTERN.match?(normalized_code) &&
          (normalized_index.nil? || normalized_index.positive?)

      super(code: normalized_code.freeze, entry_index: normalized_index)
      freeze
    end

    def as_json(*)
      { "code" => code, "entry_index" => entry_index }.compact.freeze
    end
  end

  SitemapWarning.const_set(:CODE_PATTERN, /\A[a-z][a-z0-9_]{0,63}\z/)
end
