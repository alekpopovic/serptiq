# frozen_string_literal: true

require "test_helper"

class IdentityOauthInitiatorTest < ActiveSupport::TestCase
  Request = Data.define(:remote_ip)

  test "uses a stable keyed digest without retaining a raw canonical address" do
    first = Identity::OauthInitiator.from_request(Request.new("2001:db8::1"), key: "k" * 32)
    equivalent = Identity::OauthInitiator.from_request(Request.new("2001:0db8:0:0:0:0:0:1"), key: "k" * 32)
    other = Identity::OauthInitiator.from_request(Request.new("198.51.100.1"), key: "k" * 32)

    assert_equal first.digest, equivalent.digest
    assert_not_equal first.digest, other.digest
    assert_match(/\A[0-9a-f]{64}\z/, first.digest)
    refute_includes first.inspect, "2001:db8"
  end

  test "groups malformed addresses into a non-identifying fallback dimension" do
    first = Identity::OauthInitiator.from_request(Request.new("not-an-ip"), key: "k" * 32)
    second = Identity::OauthInitiator.from_request(Request.new("still-not-an-ip"), key: "k" * 32)

    assert_equal first.digest, second.digest
    refute_includes first.inspect, "not-an-ip"
  end
end
