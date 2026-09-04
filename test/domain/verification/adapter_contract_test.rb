# frozen_string_literal: true

require "test_helper"

class VerificationAdapterContractTest < ActiveSupport::TestCase
  ChallengeStub = Struct.new(
    :expected_location, :bound_origin, :challenge_digest, :created_at, :organization_id,
    :integration_connection_id, :provider_property_identifier, :connection_revision, keyword_init: true
  )

  test "DNS adapter compares TXT proof without retaining record values" do
    value = "searchops-verification=#{SecureRandom.urlsafe_base64(32, false)}"
    challenge = stub_challenge(value, location: "_searchops-verification.example.com")
    resolver = Object.new
    resolver.define_singleton_method(:resolve) do |name:|
      Verification::DnsResolution.new(
        status: "resolved", records: [ "other", (value if name.present?) ], record_count: 2
      )
    end

    result = Verification::Adapters::DnsTxt.new(resolver: resolver).verify(
      challenge: challenge, expected_value: value
    )

    assert result.verified?
    assert_equal({
      "record_count" => 2,
      "cname_hops" => 0,
      "delegation_count" => 0,
      "question_match" => true,
      "multiple_records" => true,
      "matched" => true
    }, result.evidence)
    refute_includes result.evidence.to_json, value
  end

  test "HTML file adapter requires the exact final origin and exact body" do
    value = "searchops-verification=#{SecureRandom.urlsafe_base64(32, false)}"
    challenge = stub_challenge(value, location: "https://example.com/.well-known/searchops-verification.txt")
    response = {
      status: 200,
      final_origin: "https://other.example.com",
      final_url: "https://other.example.com/.well-known/searchops-verification.txt",
      body: value,
      redirect_count: 1,
      content_type_allowed: true,
      destination_approved: false,
      request_match: true
    }
    fetcher = Object.new
    fetcher.define_singleton_method(:fetch_exact) do |origin:, url:, **|
      response.merge(seen: [ origin, url ])
    end

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
    fetcher.define_singleton_method(:fetch_exact) do |origin:, url:, **|
      {
        status: 200,
        final_origin: origin,
        final_url: url,
        body: html,
        redirect_count: 0,
        content_type_allowed: true,
        destination_approved: true,
        request_match: true
      }
    end

    result = Verification::Adapters::MetaTag.new(fetcher: fetcher).verify(
      challenge: challenge, expected_value: value
    )

    assert result.verified?
    refute_includes result.evidence.to_json, html
  end

  test "Search Console adapter requires an exact verified property observation" do
    resolver = Object.new
    resolver.define_singleton_method(:call) do |**|
      Verification::SearchConsoleSelection.new(
        connection_id: SecureRandom.uuid,
        external_property_identifier: "https://example.com/",
        property_type: "url_prefix",
        permission_level: "siteOwner",
        checked_at: Time.current,
        connection_revision: 1
      )
    end
    challenge = stub_challenge("unused", location: "https://example.com")

    result = Verification::Adapters::SearchConsole.new(client: nil, resolver: resolver).verify(
      challenge: challenge, expected_value: "unused"
    )

    assert result.verified?
    assert_equal({
      "provider_property_match" => true,
      "provider_permission_owner" => true,
      "connection_revision_match" => true
    }, result.evidence)
    assert_equal "siteOwner", result.provider_observation.permission_level
  end

  private

  def stub_challenge(value, location:)
    ChallengeStub.new(
      expected_location: location,
      bound_origin: "https://example.com",
      challenge_digest: Verification::ChallengeToken.digest(value),
      created_at: 1.day.ago,
      organization_id: SecureRandom.uuid,
      integration_connection_id: SecureRandom.uuid,
      provider_property_identifier: "https://example.com/",
      connection_revision: 1
    )
  end
end
