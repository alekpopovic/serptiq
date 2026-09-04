# frozen_string_literal: true

require "test_helper"

class VerificationDnsTxtAdapterTest < ActiveSupport::TestCase
  ChallengeStub = Struct.new(
    :expected_location, :challenge_digest, :created_at, keyword_init: true
  )
  Resolver = Struct.new(:resolution, :names, keyword_init: true) do
    def resolve(name:)
      names << name
      resolution
    end
  end

  setup do
    @now = Time.zone.parse("2026-09-04 12:00:00")
    @value = "searchops-verification=#{SecureRandom.urlsafe_base64(32, false)}"
    @challenge = challenge(@value, created_at: @now - 1.hour)
  end

  test "requires an exact case and whitespace preserving token match" do
    [ "#{@value}x", @value.upcase, " #{@value}", "#{@value} " ].each do |near_match|
      result = adapter(resolved(near_match)).verify(challenge: @challenge, expected_value: @value)

      refute result.verified?, near_match
      assert_equal "proof_mismatch", result.failure_category
    end

    assert adapter(resolved(@value)).verify(challenge: @challenge, expected_value: @value).verified?
  end

  test "does not reuse a valid response across challenges" do
    other_value = "searchops-verification=#{SecureRandom.urlsafe_base64(32, false)}"
    other_challenge = challenge(other_value, created_at: @now - 1.hour)

    result = adapter(resolved(@value)).verify(
      challenge: other_challenge,
      expected_value: other_value
    )

    refute result.verified?
    assert_equal "proof_mismatch", result.failure_category
  end

  test "distinguishes propagation and multiple record observations" do
    recent = challenge(@value, created_at: @now - 5.minutes)
    propagation = adapter(resolved("old-value")).verify(challenge: recent, expected_value: @value)
    multiple = adapter(resolved("one", "two")).verify(challenge: @challenge, expected_value: @value)

    assert_equal "dns_propagating", propagation.failure_category
    assert_equal "dns_multiple_records", multiple.failure_category
    assert multiple.evidence.fetch("multiple_records")
  end

  test "maps resolver outcomes without retaining names records or tokens" do
    expected = {
      "nxdomain" => "dns_nxdomain",
      "no_record" => "dns_no_record",
      "timeout" => "dns_timeout",
      "transient_failure" => "dns_transient_failure",
      "response_limit" => "dns_response_limit",
      "cname_limit" => "dns_cname_limit",
      "delegation_limit" => "dns_delegation_limit",
      "malformed_response" => "malformed_response"
    }

    expected.each do |status, category|
      resolution = Verification::DnsResolution.new(status: status, record_count: 3)
      result = adapter(resolution).verify(challenge: @challenge, expected_value: @value)

      assert_equal category, result.failure_category
      refute_includes result.evidence.to_json, @value
      refute_includes result.evidence.to_json, @challenge.expected_location
    end
  end

  test "rejects an expected value that is not bound to the challenge before DNS lookup" do
    resolver = Resolver.new(resolution: resolved(@value), names: [])
    other_value = "searchops-verification=#{SecureRandom.urlsafe_base64(32, false)}"

    result = Verification::Adapters::DnsTxt.new(resolver: resolver).verify(
      challenge: @challenge, expected_value: other_value
    )

    assert_equal "malformed_response", result.failure_category
    assert_empty resolver.names
  end

  private

  def challenge(value, created_at:)
    ChallengeStub.new(
      expected_location: "_searchops-verification.example.com",
      challenge_digest: Verification::ChallengeToken.digest(value),
      created_at: created_at
    )
  end

  def resolved(*records)
    Verification::DnsResolution.new(
      status: "resolved", records: records, record_count: records.length
    )
  end

  def adapter(resolution)
    resolver = Resolver.new(resolution: resolution, names: [])
    Verification::Adapters::DnsTxt.new(resolver: resolver, clock: -> { @now })
  end
end
