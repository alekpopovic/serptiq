# frozen_string_literal: true

require "test_helper"

class CrawlingSitemapRetrievalTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:value, :calls, keyword_init: true) do
    def fetch_public_redirects(**attributes)
      calls << attributes
      raise value if value.is_a?(Exception)

      value
    end
  end

  test "uses the public destination boundary and restricts redirects to the scan origin" do
    now = Time.current.change(usec: 0)
    client = FakeClient.new(
      value: {
        status: 200,
        body: "<urlset/>",
        final_url: "https://example.com/maps/site.xml",
        redirect_count: 1,
        content_type: "application/xml"
      },
      calls: []
    )
    retrieval = Crawling::RetrieveSitemap.new(client: client, clock: -> { now }).call(
      origin: "https://example.com",
      url: "https://example.com/sitemap.xml"
    )

    assert_equal "fetched", retrieval.status
    assert_equal 200, retrieval.http_status
    assert_equal now, retrieval.retrieved_at
    assert_equal "application/xml", retrieval.content_type
    assert_equal Digest::SHA256.hexdigest("<urlset/>"), retrieval.artifact_sha256
    request = client.calls.sole
    assert_equal [ "https://example.com" ], request.fetch(:approved_redirect_origins)
    assert_equal Crawling::RetrieveSitemap::ALLOWED_CONTENT_TYPES, request.fetch(:allowed_content_types)
    assert_equal "SearchOpsBot/1.0 (+https://searchops.test/crawler)", request.fetch(:user_agent)
  end

  test "maps private or cross-origin redirects and bounded response failures without a body" do
    %w[unsafe_destination redirect_rejected response_too_large content_type_rejected].each do |reason|
      error = Shared::NetworkSafety::Error.new(
        reason_code: reason,
        evidence: { redirect_count: 1, status_code: 200 }
      )
      client = FakeClient.new(value: error, calls: [])
      result = Crawling::RetrieveSitemap.new(client: client).call(
        origin: "https://example.com",
        url: "https://example.com/sitemap.xml"
      )

      expected = if reason == "response_too_large"
        "oversized"
      elsif reason == "content_type_rejected"
        "malformed"
      else
        "unreachable"
      end
      assert_equal expected, result.status, reason
      assert_equal reason, result.error_code, reason
      assert_empty result.body, reason
    end
  end
end
