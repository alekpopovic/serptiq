# frozen_string_literal: true

require "stringio"
require "zlib"

module Crawling
  class DecodeSitemapPayload
    GZIP_MAGIC = "\x1f\x8b".b.freeze
    CHUNK_BYTES = 16.kilobytes

    def initialize(max_compressed_bytes:, max_decompressed_bytes:)
      @max_compressed_bytes = Integer(max_compressed_bytes)
      @max_decompressed_bytes = Integer(max_decompressed_bytes)
      raise ArgumentError, "sitemap payload limits are invalid" unless
        @max_compressed_bytes.between?(1024, 50.megabytes) &&
          @max_decompressed_bytes.between?(1024, 50.megabytes)
    end

    def call(body:)
      raw = body.to_s.b
      raise SitemapPayloadError, "compressed_size_limit" if raw.bytesize > @max_compressed_bytes

      gzip?(raw) ? decode_gzip(raw) : plain(raw)
    end

    private

    def gzip?(raw)
      raw.start_with?(GZIP_MAGIC)
    end

    def plain(raw)
      raise SitemapPayloadError, "decompressed_size_limit" if raw.bytesize > @max_decompressed_bytes

      SitemapPayload.new(
        xml: raw, compressed_bytes: raw.bytesize, decompressed_bytes: raw.bytesize, gzip: false
      )
    end

    def decode_gzip(raw)
      output = +"".b
      reader = Zlib::GzipReader.new(StringIO.new(raw))
      loop do
        chunk = reader.read(CHUNK_BYTES)
        break if chunk.nil? || chunk.empty?
        raise SitemapPayloadError, "decompressed_size_limit" if
          output.bytesize + chunk.bytesize > @max_decompressed_bytes

        output << chunk
      end
      reader.close
      SitemapPayload.new(
        xml: output, compressed_bytes: raw.bytesize, decompressed_bytes: output.bytesize, gzip: true
      )
    rescue SitemapPayloadError
      raise
    rescue Zlib::Error, EOFError, IOError
      raise SitemapPayloadError, "invalid_gzip", cause: nil
    ensure
      reader&.close unless reader&.closed?
    end
  end
end
