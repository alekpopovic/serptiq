# frozen_string_literal: true

require "test_helper"

class CanonicalOriginTest < ActiveSupport::TestCase
  test "normalizes HTTP HTTPS default ports trailing dots and IDNA display forms" do
    cases = {
      " HTTPS://WWW.Example.COM:443/ " => [
        "https://www.example.com", "https://www.example.com", "www.example.com", 443
      ],
      "http://www.example.com:80" => [
        "http://www.example.com", "http://www.example.com", "www.example.com", 80
      ],
      "http://www.example.com:443" => [
        "http://www.example.com:443", "http://www.example.com:443", "www.example.com", 443
      ],
      "https://BÜCHER.example.:8443/" => [
        "https://xn--bcher-kva.example:8443", "https://bücher.example:8443",
        "xn--bcher-kva.example", 8443
      ],
      "https://xn--bcher-kva.example" => [
        "https://xn--bcher-kva.example", "https://bücher.example",
        "xn--bcher-kva.example", 443
      ]
    }

    cases.each do |input, expected|
      value = Properties::CanonicalOrigin.new(origin: input)
      assert_equal expected, [ value.origin, value.display_origin, value.host, value.port ], input
      assert value.frozen?
    end
  end

  test "rejects IP literals internal names non HTTP schemes authority ambiguity and URL components" do
    invalid = [
      "https://127.0.0.1",
      "https://8.8.8.8",
      "https://0177.0.0.1",
      "https://127.1",
      "https://2130706433",
      "https://0x7f000001",
      "https://[::1]",
      "https://[2001:4860:4860::8888]",
      "https://[::ffff:127.0.0.1]",
      "https://localhost",
      "https://service.internal",
      "https://router.local",
      "https://single-label",
      "ftp://www.example.com",
      "file://www.example.com",
      "https://user@example.com",
      "https://user:password@example.com",
      "https://www.example.com/path",
      "https://www.example.com?query=yes",
      "https://www.example.com#fragment",
      "https://www.example.com:",
      "https://www.example.com..",
      "https://bad_label.example.com",
      "https://-bad.example.com",
      "https://www.example.com\\@evil.example",
      "https://www.example.com\nevil"
    ]

    invalid.each do |input|
      assert_raises(ArgumentError, input) { Properties::CanonicalOrigin.new(origin: input) }
    end
  end

  test "checks exact host and dot-delimited subdomain boundaries" do
    origin = Properties::CanonicalOrigin.new(origin: "https://example.com")

    assert origin.host_or_subdomain?("example.com")
    assert origin.host_or_subdomain?("WWW.Example.com.")
    assert origin.host_or_subdomain?("deep.www.example.com")
    refute origin.host_or_subdomain?("notexample.com")
    refute origin.host_or_subdomain?("example.com.evil.test")
  end
end
