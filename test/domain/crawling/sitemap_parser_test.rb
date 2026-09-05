# frozen_string_literal: true

require "test_helper"
require "base64"

class CrawlingSitemapParserTest < ActiveSupport::TestCase
  FIXTURES = Rails.root.join("test/fixtures/files/crawling")

  test "streams valid URL sets and indexes with bounded lastmod provenance" do
    parser = Crawling::SitemapParser.new(max_entries: 10, max_depth: 8)

    urlset = parser.call(xml: fixture("sitemap_urlset.xml"))
    index = parser.call(xml: fixture("sitemap_index.xml"))

    assert_equal "urlset", urlset.kind
    assert_equal %w[page page page page], urlset.entries.map(&:kind)
    assert_equal "2026-08-20", urlset.entries.first.lastmod
    refute urlset.malformed
    assert_equal "sitemap_index", index.kind
    assert_equal %w[sitemap sitemap], index.entries.map(&:kind)
    assert_empty index.warnings
  end

  test "reports malformed XML without exposing untrusted partial parser state" do
    result = parser.call(xml: fixture("sitemap_malformed.xml"))

    assert result.malformed
    assert_empty result.entries
    assert_includes result.warnings.map(&:code), "malformed_xml"
  end

  test "retains bounded usable entries around structurally partial records" do
    result = parser.call(xml: fixture("sitemap_partial.xml"))

    refute result.malformed
    assert_equal [ "https://example.com/partial", "not a URL" ], result.entries.map(&:location)
    assert_includes result.warnings.map(&:code), "location_missing"
  end

  test "rejects DTD and external entity constructs without expanding content" do
    result = parser.call(xml: fixture("sitemap_xxe.xml"))

    assert result.malformed
    assert_empty result.entries
    assert_includes result.warnings.map(&:code), "forbidden_xml_construct"
    refute_includes result.entries.map(&:location).join, "root:"
  end

  test "bounds XML nesting and entry count" do
    deep = "<urlset>#{'<x>' * 8}#{'</x>' * 8}</urlset>"
    depth_result = Crawling::SitemapParser.new(max_entries: 10, max_depth: 4).call(xml: deep)
    entries = <<~XML
      <urlset xmlns="#{Crawling::SitemapParser::NAMESPACE}">
        <url><loc>https://example.com/one</loc></url>
        <url><loc>https://example.com/two</loc></url>
      </urlset>
    XML
    count_result = Crawling::SitemapParser.new(max_entries: 1, max_depth: 8).call(xml: entries)

    assert depth_result.malformed
    assert_includes depth_result.warnings.map(&:code), "xml_depth_limit"
    assert count_result.malformed
    assert_equal [ "https://example.com/one" ], count_result.entries.map(&:location)
    assert_includes count_result.warnings.map(&:code), "entry_limit"
  end

  test "decodes gzip incrementally and rejects decompression bombs and invalid gzip" do
    xml = fixture("sitemap_urlset.xml")
    decoder = Crawling::DecodeSitemapPayload.new(
      max_compressed_bytes: 10_000,
      max_decompressed_bytes: 2000
    )
    payload = decoder.call(body: encoded_fixture("sitemap_urlset.xml.gz.b64"))

    assert payload.gzip
    assert_equal xml.b, payload.xml
    assert_operator payload.compressed_bytes, :<, payload.decompressed_bytes

    bomb = encoded_fixture("sitemap_decompression_bomb.gz.b64")
    error = assert_raises(Crawling::SitemapPayloadError) do
      Crawling::DecodeSitemapPayload.new(
        max_compressed_bytes: 10_000,
        max_decompressed_bytes: 1024
      ).call(body: bomb)
    end
    assert_equal "decompressed_size_limit", error.reason_code

    malformed = assert_raises(Crawling::SitemapPayloadError) do
      decoder.call(body: "\x1f\x8bnot-gzip".b)
    end
    assert_equal "invalid_gzip", malformed.reason_code
  end

  private

  def parser
    Crawling::SitemapParser.new(max_entries: 10, max_depth: 8)
  end

  def fixture(name)
    FIXTURES.join(name).binread
  end

  def encoded_fixture(name)
    Base64.strict_decode64(fixture(name).strip)
  end
end
