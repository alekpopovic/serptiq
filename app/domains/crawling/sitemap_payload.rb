# frozen_string_literal: true

module Crawling
  SitemapPayload = Data.define(:xml, :compressed_bytes, :decompressed_bytes, :gzip) do
    def initialize(xml:, compressed_bytes:, decompressed_bytes:, gzip:)
      super(
        xml: xml.to_s.b.freeze,
        compressed_bytes: Integer(compressed_bytes),
        decompressed_bytes: Integer(decompressed_bytes),
        gzip: gzip == true
      )
      freeze
    end
  end
end
