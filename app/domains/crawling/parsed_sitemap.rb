# frozen_string_literal: true

module Crawling
  ParsedSitemap = Data.define(:kind, :entries, :warnings, :parser_version, :malformed) do
    def initialize(kind:, entries:, warnings:, parser_version:, malformed: false)
      normalized_kind = kind.to_s
      raise ArgumentError, "parsed sitemap kind is invalid" unless
        ParsedSitemap::KINDS.include?(normalized_kind)

      super(
        kind: normalized_kind.freeze,
        entries: Array(entries).freeze,
        warnings: Array(warnings).freeze,
        parser_version: Integer(parser_version),
        malformed: malformed == true
      )
      freeze
    end
  end

  ParsedSitemap.const_set(:KINDS, %w[urlset sitemap_index unknown].freeze)
end
