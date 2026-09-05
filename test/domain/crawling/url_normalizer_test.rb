# frozen_string_literal: true

require "test_helper"

class CrawlingUrlNormalizerTest < ActiveSupport::TestCase
  test "normalization version two has deterministic HTTP URL and percent encoding rules" do
    cases = {
      "HTTPS://EXAMPLE.COM:443" => [ "https://example.com/", "https://example.com/" ],
      "http://EXAMPLE.com.:80/a/./b/../c#section" => [
        "http://example.com/a/c", "http://example.com/a/c"
      ],
      "https://BÜCHER.example.:8443/café" => [
        "https://xn--bcher-kva.example:8443/caf%C3%A9",
        "https://xn--bcher-kva.example:8443/caf%C3%A9"
      ],
      "https://example.com/a/%7e/%41/%2f" => [
        "https://example.com/a/~/A/%2F", "https://example.com/a/~/A/%2F"
      ],
      "https://example.com/a//b/" => [
        "https://example.com/a//b/", "https://example.com/a//b/"
      ],
      "https://example.com/path?z=2&a=1" => [
        "https://example.com/path?z=2&a=1", "https://example.com/path?a=1&z=2"
      ],
      "https://example.com/path?b=0&a=2&a=1" => [
        "https://example.com/path?b=0&a=2&a=1", "https://example.com/path?a=2&a=1&b=0"
      ],
      "https://example.com/path?flag&empty=" => [
        "https://example.com/path?flag&empty=", "https://example.com/path?empty=&flag"
      ],
      "https://example.com/search?q=a+b&q=a%20b&next=%2fdocs%3fa%3d1" => [
        "https://example.com/search?q=a+b&q=a%20b&next=%2Fdocs%3Fa%3D1",
        "https://example.com/search?next=%2Fdocs%3Fa%3D1&q=a+b&q=a%20b"
      ],
      "http://example.com:80" => [ "http://example.com/", "http://example.com/" ],
      "https://example.com:444" => [ "https://example.com:444/", "https://example.com:444/" ],
      "https://example.com/a/b/../../" => [ "https://example.com/", "https://example.com/" ],
      "https://example.com/a/.." => [ "https://example.com/", "https://example.com/" ],
      "https://example.com/%2e/%2E%2e/x" => [ "https://example.com/x", "https://example.com/x" ],
      "https://example.com/a/%2E/b" => [ "https://example.com/a/b", "https://example.com/a/b" ],
      "https://example.com/a/%2e%2e/b" => [ "https://example.com/b", "https://example.com/b" ],
      "https://example.com/%62" => [ "https://example.com/b", "https://example.com/b" ],
      "https://example.com/€" => [ "https://example.com/%E2%82%AC", "https://example.com/%E2%82%AC" ],
      "https://example.com/?%7e=%41" => [ "https://example.com/?~=A", "https://example.com/?~=A" ],
      "https://example.com/?q=€" => [
        "https://example.com/?q=%E2%82%AC", "https://example.com/?q=%E2%82%AC"
      ],
      "https://example.com/?a=3&a=2&a=1" => [
        "https://example.com/?a=3&a=2&a=1", "https://example.com/?a=3&a=2&a=1"
      ],
      "https://example.com/path?" => [ "https://example.com/path", "https://example.com/path" ],
      "http://BÜCHER.example:80/über?q=grün" => [
        "http://xn--bcher-kva.example/%C3%BCber?q=gr%C3%BCn",
        "http://xn--bcher-kva.example/%C3%BCber?q=gr%C3%BCn"
      ],
      "https://example.com/#ignored" => [ "https://example.com/", "https://example.com/" ]
    }

    cases.each do |input, (fetch_url, identity_url)|
      result = normalize(input)
      assert_equal fetch_url, result.fetch_url, input
      assert_equal identity_url, result.identity_url, input
      assert_equal 2, result.normalization_version
      assert_match(/\A[0-9a-f]{64}\z/, result.identity_digest)
      assert result.frozen?
    end
  end

  test "query identity removes tracking parameters and applies exact allow and deny lists" do
    tracking = normalize(
      "https://example.com/product?id=7&utm_source=newsletter&FBCLID=abc&lang=en",
      query_handling: "tracking_only"
    )
    filtered = normalize(
      "https://example.com/product?lang=en&session_id=secret&id=7&view=full",
      query_handling: "all",
      query_parameter_allowlist: %w[id lang],
      query_parameter_denylist: %w[session_id]
    )
    ignored = normalize(
      "https://example.com/product?id=7&lang=en",
      query_handling: "ignore"
    )

    assert_equal "https://example.com/product?id=7&utm_source=newsletter&FBCLID=abc&lang=en",
      tracking.fetch_url
    assert_equal "https://example.com/product?id=7&lang=en", tracking.identity_url
    assert_equal "https://example.com/product?lang=en&session_id=secret&id=7&view=full", filtered.fetch_url
    assert_equal "https://example.com/product?id=7&lang=en", filtered.identity_url
    assert_equal "https://example.com/product?id=7&lang=en", ignored.fetch_url
    assert_equal "https://example.com/product", ignored.identity_url
  end

  test "fetch variants can share one identity without changing the requested semantic URL" do
    first = normalize(
      "https://example.com/product?id=7&utm_source=one",
      query_handling: "tracking_only"
    )
    second = normalize(
      "https://example.com/product?utm_source=two&id=7",
      query_handling: "tracking_only"
    )

    refute_equal first.fetch_url, second.fetch_url
    assert_equal first.identity_url, second.identity_url
    assert_equal first.identity_digest, second.identity_digest
  end

  test "rejects hostile ambiguous and unsupported URL forms" do
    invalid = [
      "", " https://example.com/", "https://example.com/ ",
      "https://example.com/a b", "https://example.com\\@evil.test/",
      "https://example.com/\nnext", "ftp://example.com/", "file://example.com/",
      "//example.com/path", "https://user@example.com/", "https://user:secret@example.com/",
      "https://127.0.0.1/", "https://0177.0.0.1/", "https://127.1/",
      "https://2130706433/", "https://0x7f000001/", "https://[::1]/",
      "https://example.com:0/", "https://example.com:65536/", "https://example.com:/",
      "https://localhost/", "https://example.com/%", "https://example.com/%2G",
      "https://example.com/%00", "https://example.com/?value=%0A",
      "https://example.com/?" + ("a=1&" * 101)
    ]

    invalid.each do |input|
      assert_raises(ArgumentError, input.inspect) { normalize(input) }
    end
  end

  test "normalization is idempotent and parser fuzz never leaks unexpected exceptions" do
    random = Random.new(65)
    samples = 300.times.map do
      Array.new(random.rand(0..96)) { random.rand(0..255) }.pack("C*").force_encoding(Encoding::UTF_8)
    end
    samples.concat(200.times.map do |index|
      value = random.rand(10_000)
      "https://Sub#{index}.Example.com/a/../p%61th/#{value}?z=#{value}&a=%2F#fragment"
    end)

    samples.each do |sample|
      result = normalize(sample)
      replay = normalize(result.identity_url)
      assert_equal result.identity_url, replay.identity_url
      assert_equal result.identity_digest, replay.identity_digest
    rescue ArgumentError
      # Rejection is the complete public failure contract for arbitrary bytes.
    end
  end

  test "version one fixtures retain their historical identity and digest" do
    fixtures = JSON.parse(
      Rails.root.join("test/fixtures/files/crawling/url_normalization_v1.json").read
    )

    fixtures.each do |fixture|
      result = normalize(fixture.fetch("input"), normalization_version: 1)
      assert_equal fixture.fetch("identity_url"), result.identity_url
      assert_equal fixture.fetch("identity_digest"), result.identity_digest
      assert_equal 1, result.normalization_version
    end
  end

  private

  def normalize(url, **options)
    Crawling::Public.normalize_url(url: url, **options)
  end
end
