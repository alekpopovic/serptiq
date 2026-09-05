# frozen_string_literal: true

require "test_helper"

class CrawlingHtmlPageExtractorTest < ActiveSupport::TestCase
  setup do
    @scope = Crawling::UrlScopePolicy.new(
      origin: "https://example.com",
      max_depth: 3,
      query_handling: "tracking_only"
    )
    @extractor = Crawling::HtmlPageExtractor.new
  end

  test "extracts bounded facts and resolves base canonical hreflang links images and schema" do
    result = extract(file_fixture("crawling/html/extraction_document.html").binread)

    assert_equal "parsed", result.parse_status
    assert_equal "https://example.com/docs/", result.effective_base_url
    assert_equal "Search & Discovery Guide", result.title_summary
    assert_equal "present", result.title_status
    assert_equal "A concise <b>guide</b> for search teams.", result.description_summary
    assert_equal "en-US", result.document_language
    assert_equal %w[follow max-snippet:120 noindex],
      result.meta_directives.find { |item| item["name"] == "robots" }.fetch("tokens")
    assert_equal [ 1, 2 ], result.headings.map { |heading| heading.fetch("level") }
    assert_equal "Search <script>alert(1)</script>", result.headings.first.fetch("text_summary")
    assert_equal "https://example.com/guide", result.canonicals.sole.fetch("url")
    assert_equal %w[en fr-fr], result.hreflangs.map { |item| item.fetch("language") }
    assert_equal "https://example.com/docs/images/hero.png", result.images.sole.fetch("url")
    assert_equal "Hero <svg onload=alert(1)>", result.images.sole.fetch("alt_summary")
    assert_equal %w[present malformed], result.structured_data_blocks.map { |item| item.fetch("status") }
    assert_equal "Article", result.structured_data_blocks.first.dig("data", "@type")
  end

  test "deduplicates directed destinations while retaining occurrence nofollow and anchor evidence" do
    result = extract(file_fixture("crawling/html/extraction_document.html").binread)
    about = result.links.find { |link| link.destination_url == "https://example.com/about?b=2" }

    assert_equal 3, result.links.length
    assert_equal "internal", about.classification
    assert_equal "allowed", about.scope_status
    assert_equal 2, about.occurrence_count
    assert_equal 1, about.nofollow_count
    assert_equal %w[nofollow sponsored], about.rel_tokens
    assert_equal "About us", about.anchor_summary
    assert_equal 1, result.counts.fetch("invalid_links")
    external = result.links.find { |link| link.classification == "external" }
    assert_equal "denied", external.scope_status
    assert_equal "host_out_of_scope", external.scope_reason
  end

  test "marks absent malformed and hostile snippets without producing executable markup" do
    result = extract(file_fixture("crawling/html/malformed_adversarial.html").binread)

    assert_equal "malformed", result.fact_statuses.fetch("base")
    assert_equal "malformed", result.title_status
    assert_equal "absent", result.description_status
    assert_equal "malformed", result.language_status
    assert_equal "malformed", result.fact_statuses.fetch("canonical")
    assert_equal "malformed", result.fact_statuses.fetch("structured_data")
    assert_equal 1, result.links.length
    assert_equal "https://example.com/safe", result.links.sole.destination_url
    escaped = ERB::Util.html_escape(result.links.sole.anchor_summary)
    assert_includes escaped, "&lt;script&gt;"
    refute_includes escaped, "<script>"
    assert_equal %w[present malformed], result.images.map { |image| image.fetch("status") }
    image_alt = result.images.last.fetch("alt_summary")
    assert_includes ERB::Util.html_escape(image_alt), "&lt;img"
  end

  test "rejects bodies and element sets above hard extraction ceilings" do
    oversized = "x" * (Crawling::HtmlPageExtractor::MAX_HTML_BYTES + 1)
    error = assert_raises(Crawling::Invalid) { extract(oversized) }
    assert_equal "extraction_body_too_large", error.reason_code

    html = "<div></div>" * (Crawling::HtmlPageExtractor::MAX_ELEMENTS + 1)
    error = assert_raises(Crawling::Invalid) { extract(html) }
    assert_equal "html_element_limit_exceeded", error.reason_code
  end

  test "bounds attributes snippets collections and structured data" do
    huge_attribute = "a" * (Crawling::HtmlPageExtractor::MAX_ATTRIBUTE_BYTES + 1)
    huge_json = JSON.generate("payload" => "x" * Crawling::HtmlPageExtractor::MAX_STRUCTURED_DATA_BYTES)
    headings = (Crawling::HtmlPageExtractor::MAX_HEADINGS + 10).times.map do |index|
      "<h2>Heading #{index} #{"x" * 600}</h2>"
    end.join
    html = <<~HTML
      <title>#{"T" * 3000}</title>
      <base href="#{huge_attribute}">
      <img src="/empty-alt" alt="">
      <img src="/huge-alt" alt="#{huge_attribute}">
      #{headings}
      <script type="application/ld+json">#{huge_json}</script>
    HTML
    result = extract(html)

    assert_equal "malformed", result.fact_statuses.fetch("base")
    assert_operator result.title_summary.bytesize, :<=, 512
    assert_equal Crawling::HtmlPageExtractor::MAX_HEADINGS, result.headings.length
    assert result.headings.all? { |heading| heading.fetch("text_summary").bytesize <= 512 }
    assert_equal %w[empty malformed], result.images.map { |image| image.fetch("alt_status") }
    assert_equal "too_large", result.structured_data_blocks.sole.fetch("status")
    refute result.structured_data_blocks.sole.key?("data")
  end

  private

  def extract(body)
    @extractor.call(
      body: body,
      document_url: "https://example.com/source/index.html",
      scope: @scope,
      depth: 0,
      settings: { "query_handling" => "tracking_only" }
    )
  end
end
