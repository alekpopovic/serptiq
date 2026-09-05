# frozen_string_literal: true

module Crawling
  SitemapParsedEntry = Data.define(:kind, :location, :lastmod, :entry_index) do
    def initialize(kind:, location:, lastmod:, entry_index:)
      normalized_kind = kind.to_s
      normalized_location = location&.to_s
      normalized_lastmod = lastmod&.to_s
      normalized_index = Integer(entry_index)
      raise ArgumentError, "sitemap entry is invalid" unless
        SitemapParsedEntry::KINDS.include?(normalized_kind) && normalized_index.positive? &&
          (normalized_location.nil? || normalized_location.bytesize <= SitemapParser::MAXIMUM_FIELD_BYTES) &&
          (normalized_lastmod.nil? || normalized_lastmod.bytesize <= SitemapParser::MAXIMUM_LASTMOD_BYTES)

      super(
        kind: normalized_kind.freeze,
        location: normalized_location&.freeze,
        lastmod: normalized_lastmod&.freeze,
        entry_index: normalized_index
      )
      freeze
    end
  end

  SitemapParsedEntry.const_set(:KINDS, %w[page sitemap].freeze)
end
