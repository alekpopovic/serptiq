# frozen_string_literal: true

require "test_helper"

class HtmlExtractionPerformanceTest < ActiveSupport::TestCase
  test "extracts a large bounded document within the regression budget" do
    links = 4000.times.map do |index|
      %(<a href="/pages/#{index % 1000}" rel="#{index.even? ? "nofollow" : "ugc"}">Page #{index}</a>)
    end.join
    images = 400.times.map do |index|
      %(<img src="/images/#{index}.png" alt="Image #{index}" width="640" height="480">)
    end.join
    body = "<!doctype html><title>Large</title><body>#{links}#{images}</body>"
    scope = Crawling::UrlScopePolicy.new(origin: "https://example.com", max_depth: 4)

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = Crawling::HtmlPageExtractor.new.call(
      body: body,
      document_url: "https://example.com/",
      scope: scope,
      depth: 0
    )
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    assert_equal 1000, result.links.length
    assert_equal 400, result.images.length
    assert_equal 4000, result.links.sum(&:occurrence_count)

    assert_operator elapsed, :<, 5.0,
      "bounded HTML extraction took #{elapsed.round(3)}s; expected less than 5s"
  end
end
