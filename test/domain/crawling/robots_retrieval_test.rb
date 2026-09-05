# frozen_string_literal: true

require "test_helper"

class CrawlingRobotsRetrievalTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:responses, :calls, keyword_init: true) do
    def fetch_public_redirects(**attributes)
      calls << attributes
      response = responses.shift
      raise response if response.is_a?(Exception)

      response
    end
  end

  test "fetches the exact top-level file with the honest SearchOps identity" do
    now = Time.current.change(usec: 0)
    client = fake_client(response(200, body: "User-agent: *\nDisallow: /private\n"))
    result = Crawling::RetrieveRobots.new(client: client, clock: -> { now }).call(
      origin: "https://example.com"
    )

    assert_equal "fetched", result.status
    assert_equal 200, result.http_status
    assert_equal now, result.retrieved_at
    assert_equal Digest::SHA256.hexdigest(result.body), result.artifact_sha256
    request = client.calls.sole
    assert_equal "https://example.com/robots.txt", request.fetch(:url)
    assert_equal [ "text/plain" ], request.fetch(:allowed_content_types)
    assert_equal "SearchOpsBot/1.0 (+https://searchops.test/crawler)", request.fetch(:user_agent)
  end

  test "maps RFC unavailable and unreachable HTTP statuses explicitly" do
    unavailable = retrieve(response(404, body: "missing"))
    unreachable = retrieve(response(503, body: "retry later"))
    unresolved_redirect = retrieve(response(304))

    assert_equal [ "unavailable", 404 ], [ unavailable.status, unavailable.http_status ]
    assert_equal [ "unreachable", 503, "http_unreachable" ],
      [ unreachable.status, unreachable.http_status, unreachable.error_code ]
    assert_equal "unreachable", unresolved_redirect.status
  end

  test "maps timeout redirect oversize and malformed-content failures without leaking payloads" do
    cases = {
      "timeout" => "unreachable",
      "redirect_limit" => "unreachable",
      "response_too_large" => "oversized",
      "content_type_rejected" => "malformed"
    }

    cases.each do |reason, status|
      error = Shared::NetworkSafety::Error.new(
        reason_code: reason,
        evidence: { redirect_count: 5, byte_count: 512_001, status_code: 200 }
      )
      result = retrieve(error)
      assert_equal status, result.status, reason
      assert_equal reason, result.error_code, reason
      assert_empty result.body
      assert_nil result.artifact_sha256
    end
  end

  private

  def retrieve(value)
    Crawling::RetrieveRobots.new(client: fake_client(value)).call(origin: "https://example.com")
  end

  def fake_client(*responses)
    FakeClient.new(responses: responses, calls: [])
  end

  def response(status, body: "", final_url: "https://example.com/robots.txt", redirect_count: 0)
    {
      status: status,
      body: body,
      final_url: final_url,
      redirect_count: redirect_count
    }
  end
end
