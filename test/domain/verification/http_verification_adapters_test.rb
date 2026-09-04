# frozen_string_literal: true

require "test_helper"

class VerificationHttpAdaptersTest < ActiveSupport::TestCase
  ChallengeStub = Struct.new(
    :bound_origin, :expected_location, :challenge_digest, keyword_init: true
  )
  FakeFetcher = Struct.new(:response, :error, :calls, keyword_init: true) do
    def fetch_exact(**attributes)
      calls << attributes
      raise error if error

      response
    end
  end

  setup do
    @value = "searchops-verification=#{SecureRandom.urlsafe_base64(32, false)}"
    @origin = "https://example.com"
  end

  test "HTML file requires the complete byte-exact plain-text token" do
    challenge = challenge(path: "/.well-known/searchops-verification.txt")
    exact = html_adapter(response(body: @value, final_url: challenge.expected_location))
    newline = html_adapter(response(body: "#{@value}\n", final_url: challenge.expected_location))

    assert exact.verify(challenge: challenge, expected_value: @value).verified?
    mismatch = newline.verify(challenge: challenge, expected_value: @value)
    refute mismatch.verified?
    assert_equal "proof_mismatch", mismatch.failure_category
  end

  test "meta verification requires exactly one static exact tag" do
    challenge = challenge(path: "/")
    exact_html = %(<html><head><meta name="searchops-verification" content="#{@value}"></head></html>)
    duplicate_html = exact_html.sub("</head>", %(<meta name="searchops-verification" content="#{@value}"></head>))
    script_html = %(<script>document.write('<meta name="searchops-verification" content="#{@value}">')</script>)

    success = meta_adapter(response(body: exact_html, final_url: challenge.expected_location))
      .verify(challenge: challenge, expected_value: @value)
    duplicate = meta_adapter(response(body: duplicate_html, final_url: challenge.expected_location))
      .verify(challenge: challenge, expected_value: @value)
    script_only = meta_adapter(response(body: script_html, final_url: challenge.expected_location))
      .verify(challenge: challenge, expected_value: @value)

    assert success.verified?
    assert_equal "duplicate_meta", duplicate.failure_category
    assert_equal 2, duplicate.evidence.fetch("meta_count")
    assert_equal "proof_mismatch", script_only.failure_category
  end

  test "meta token does not accept case or whitespace near matches" do
    challenge = challenge(path: "/")
    [ @value.upcase, " #{@value}", "#{@value} " ].each do |observed|
      html = %(<meta name="searchops-verification" content="#{observed}">)
      result = meta_adapter(response(body: html, final_url: challenge.expected_location))
        .verify(challenge: challenge, expected_value: @value)

      refute result.verified?
      assert_equal "proof_mismatch", result.failure_category
    end
  end

  test "explicitly approved canonical redirect can retain the exact path" do
    challenge = challenge(path: "/.well-known/searchops-verification.txt")
    redirected = response(
      body: @value,
      final_origin: "https://www.example.com",
      final_url: "https://www.example.com/.well-known/searchops-verification.txt",
      redirect_count: 1,
      final_origin_match: false
    )
    fetcher = FakeFetcher.new(response: redirected, calls: [])

    result = Verification::Adapters::HtmlFile.new(fetcher: fetcher).verify(
      challenge: challenge, expected_value: @value
    )

    assert result.verified?
    assert_equal [ "https://www.example.com" ],
      fetcher.calls.sole.fetch(:approved_redirect_origins).grep(/www/)
    refute result.evidence.fetch("final_origin_match")
  end

  test "safe-client rejection maps to a bounded category and evidence only" do
    challenge = challenge(path: "/")
    error = Shared::NetworkSafety::Error.new(
      reason_code: "response_too_large",
      evidence: { status_code: 200, byte_count: 262_145, raw_body: @value }
    )
    fetcher = FakeFetcher.new(error: error, calls: [])

    result = Verification::Adapters::MetaTag.new(fetcher: fetcher).verify(
      challenge: challenge, expected_value: @value
    )

    assert_equal "http_response_too_large", result.failure_category
    assert_equal({ "status_code" => 200, "byte_count" => 262_145 }, result.evidence)
    refute_includes result.evidence.to_json, @value
  end

  private

  def challenge(path:)
    ChallengeStub.new(
      bound_origin: @origin,
      expected_location: "#{@origin}#{path}",
      challenge_digest: Verification::ChallengeToken.digest(@value)
    )
  end

  def response(body:, final_url:, final_origin: @origin, redirect_count: 0, final_origin_match: true)
    {
      status: 200,
      body: body,
      final_origin: final_origin,
      final_url: final_url,
      redirect_count: redirect_count,
      content_type_allowed: true,
      destination_approved: true,
      request_match: true,
      final_origin_match: final_origin_match
    }
  end

  def html_adapter(value)
    Verification::Adapters::HtmlFile.new(fetcher: FakeFetcher.new(response: value, calls: []))
  end

  def meta_adapter(value)
    Verification::Adapters::MetaTag.new(fetcher: FakeFetcher.new(response: value, calls: []))
  end
end
