# frozen_string_literal: true

require "test_helper"

class VerificationAdapterContractTest < ActiveSupport::TestCase
  ChallengeStub = Struct.new(:expected_location, :bound_origin, :challenge_digest, keyword_init: true)

  test "DNS adapter compares TXT proof without retaining record values" do
    value = "searchops-verification=#{SecureRandom.urlsafe_base64(32, false)}"
    challenge = stub_challenge(value, location: "_searchops-verification.example.com")
    resolver = Object.new
    resolver.define_singleton_method(:txt_records) { |name:| [ "other", (value if name.present?) ] }

    result = Verification::Adapters::DnsTxt.new(resolver: resolver).verify(
      challenge: challenge, expected_value: value
    )

    assert result.verified?
    assert_equal({ "matched" => true, "record_count" => 2 }, result.evidence)
    refute_includes result.evidence.to_json, value
  end

  test "HTML file adapter requires the exact final origin and exact body" do
    value = "searchops-verification=#{SecureRandom.urlsafe_base64(32, false)}"
    challenge = stub_challenge(value, location: "https://example.com/.well-known/searchops-verification.txt")
    response = { status: 200, final_origin: "https://other.example.com", body: value }
    fetcher = Object.new
    fetcher.define_singleton_method(:fetch_exact) { |origin:, url:| response.merge(seen: [ origin, url ]) }

    result = Verification::Adapters::HtmlFile.new(fetcher: fetcher).verify(
      challenge: challenge, expected_value: value
    )

    refute result.verified?
    assert_equal "unsafe_destination", result.failure_category
    refute_includes result.evidence.to_json, value
  end

  test "meta adapter parses only the named meta element and stores no HTML" do
    value = "searchops-verification=#{SecureRandom.urlsafe_base64(32, false)}"
    challenge = stub_challenge(value, location: "https://example.com/")
    html = %(<html><head><meta name="searchops-verification" content="#{value}"></head></html>)
    fetcher = Object.new
    fetcher.define_singleton_method(:fetch_exact) do |origin:, url:|
      { status: 200, final_origin: origin, body: html, url: url }
    end

    result = Verification::Adapters::MetaTag.new(fetcher: fetcher).verify(
      challenge: challenge, expected_value: value
    )

    assert result.verified?
    refute_includes result.evidence.to_json, html
  end

  test "Search Console adapter requires an exact verified property observation" do
    client = Object.new
    client.define_singleton_method(:verified_property?) { |origin:| origin == "https://example.com" }
    challenge = stub_challenge("unused", location: "https://example.com")

    result = Verification::Adapters::SearchConsole.new(client: client).verify(
      challenge: challenge, expected_value: "unused"
    )

    assert result.verified?
    assert_equal({ "provider_property_match" => true }, result.evidence)
  end

  private

  def stub_challenge(value, location:)
    ChallengeStub.new(
      expected_location: location,
      bound_origin: "https://example.com",
      challenge_digest: Verification::ChallengeToken.digest(value)
    )
  end
end
