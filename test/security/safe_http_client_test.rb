# frozen_string_literal: true

require "test_helper"

class SafeHttpClientTest < ActiveSupport::TestCase
  FixtureResolver = Struct.new(:addresses, :calls, keyword_init: true) do
    def resolve(host:)
      calls << host
      addresses.fetch(host)
    end
  end
  FixtureAddressPolicy = Struct.new(:fixture_host, keyword_init: true) do
    def approve!(host:, port:, addresses:)
      raise Shared::NetworkSafety::Error.new(reason_code: "unsafe_destination") unless
        host == fixture_host && port.positive? && addresses == [ "127.0.0.1" ]

      addresses
    end
  end
  RecordingTransport = Struct.new(:responses, :calls, keyword_init: true) do
    def get(**attributes)
      calls << attributes
      responses.shift
    end
  end

  setup do
    @fixture = TestSupport::Network::MaliciousHttpFixture.new.start
    @host = "fixture.example"
    @origin = "http://#{@host}:#{@fixture.port}"
    @resolver = FixtureResolver.new(addresses: { @host => [ "127.0.0.1" ] }, calls: [])
  end

  teardown { @fixture.stop }

  test "reuses the hostile fixture and rejects its private metadata redirect before connecting" do
    error = assert_raises(Shared::NetworkSafety::Error) do
      fixture_client.fetch_exact(
        origin: @origin,
        url: "#{@origin}/redirect-private",
        allowed_content_types: [ "text/plain" ]
      )
    end

    assert_equal "redirect_rejected", error.reason_code
    assert_equal 1, @fixture.request_count
    assert_equal [ @host ], @resolver.calls
  end

  test "caps streamed response bytes and rejects unexpected content type" do
    oversized = assert_raises(Shared::NetworkSafety::Error) do
      fixture_client(max_response_bytes: 1024).fetch_exact(
        origin: @origin,
        url: "#{@origin}/oversized",
        allowed_content_types: [ "text/plain" ]
      )
    end
    assert_equal "response_too_large", oversized.reason_code

    malformed = assert_raises(Shared::NetworkSafety::Error) do
      fixture_client.fetch_exact(
        origin: @origin,
        url: "#{@origin}/malformed",
        allowed_content_types: [ "text/html" ]
      )
    end
    assert_equal "content_type_rejected", malformed.reason_code
    assert_equal false, malformed.evidence.fetch(:content_type_allowed)
  end

  test "bounds redirect loops and re-resolves every accepted hop" do
    resolver = FixtureResolver.new(addresses: { "example.com" => [ "93.184.216.34" ] }, calls: [])
    transport = RecordingTransport.new(
      responses: [
        response(302, location: "/redirect-loop"),
        response(302, location: "/redirect-loop")
      ],
      calls: []
    )
    client = Shared::NetworkSafety::SafeHttpClient.new(
      resolver: resolver, transport: transport, max_redirects: 1
    )
    error = assert_raises(Shared::NetworkSafety::Error) do
      client.fetch_exact(
        origin: "https://example.com",
        url: "https://example.com/redirect-loop",
        allowed_content_types: [ "text/plain" ]
      )
    end

    assert_equal "redirect_limit", error.reason_code
    assert_equal 2, error.evidence.fetch(:redirect_count)
    assert_equal [ "example.com", "example.com" ], resolver.calls
  end

  test "passes an explicit bounded crawler identity to the transport" do
    resolver = FixtureResolver.new(addresses: { "example.com" => [ "93.184.216.34" ] }, calls: [])
    transport = RecordingTransport.new(
      responses: [ response(200, content_type: "text/plain", body: "robots") ],
      calls: []
    )
    client = Shared::NetworkSafety::SafeHttpClient.new(resolver: resolver, transport: transport)

    client.fetch_exact(
      origin: "https://example.com",
      url: "https://example.com/robots.txt",
      allowed_content_types: [ "text/plain" ],
      user_agent: "SearchOpsBot/1.0 (+https://searchops.test/crawler)"
    )

    assert_equal "SearchOpsBot/1.0 (+https://searchops.test/crawler)",
      transport.calls.first.fetch(:user_agent)
  end

  test "follows public robots redirects across authorities and revalidates every hop" do
    resolver = FixtureResolver.new(
      addresses: {
        "example.com" => [ "93.184.216.34" ],
        "robots.example.net" => [ "93.184.216.35" ]
      },
      calls: []
    )
    transport = RecordingTransport.new(
      responses: [
        response(302, location: "https://robots.example.net/policy/current.txt"),
        response(200, content_type: "text/plain", body: "User-agent: *\nAllow: /\n")
      ],
      calls: []
    )
    client = Shared::NetworkSafety::SafeHttpClient.new(resolver: resolver, transport: transport, max_redirects: 5)

    result = client.fetch_public_redirects(
      origin: "https://example.com",
      url: "https://example.com/robots.txt",
      allowed_content_types: [ "text/plain" ],
      user_agent: "SearchOpsBot/1.0"
    )

    assert_equal "https://robots.example.net/policy/current.txt", result.fetch(:final_url)
    assert_equal 1, result.fetch(:redirect_count)
    assert_equal [ "example.com", "robots.example.net" ], resolver.calls
    assert_equal [ "93.184.216.34", "93.184.216.35" ],
      transport.calls.map { |call| call.fetch(:ip_address) }
  end

  test "rejects unsafe robots redirect destinations and HTTPS downgrade" do
    resolver = FixtureResolver.new(
      addresses: {
        "example.com" => [ "93.184.216.34" ],
        "metadata.example.net" => [ "169.254.169.254" ]
      },
      calls: []
    )
    transport = RecordingTransport.new(
      responses: [ response(302, location: "https://metadata.example.net/latest") ],
      calls: []
    )
    client = Shared::NetworkSafety::SafeHttpClient.new(resolver: resolver, transport: transport)

    unsafe = assert_raises(Shared::NetworkSafety::Error) do
      client.fetch_public_redirects(
        origin: "https://example.com", url: "https://example.com/robots.txt",
        allowed_content_types: [ "text/plain" ]
      )
    end
    assert_equal "unsafe_destination", unsafe.reason_code

    downgrade_transport = RecordingTransport.new(
      responses: [ response(302, location: "http://example.com/robots.txt") ], calls: []
    )
    downgrade_client = Shared::NetworkSafety::SafeHttpClient.new(
      resolver: FixtureResolver.new(addresses: { "example.com" => [ "93.184.216.34" ] }, calls: []),
      transport: downgrade_transport
    )
    downgrade = assert_raises(Shared::NetworkSafety::Error) do
      downgrade_client.fetch_public_redirects(
        origin: "https://example.com", url: "https://example.com/robots.txt",
        allowed_content_types: [ "text/plain" ]
      )
    end
    assert_equal "redirect_rejected", downgrade.reason_code
  end

  test "allows only an explicit canonical variant while preserving the exact path" do
    resolver = FixtureResolver.new(
      addresses: {
        "example.com" => [ "93.184.216.34" ],
        "www.example.com" => [ "93.184.216.35" ]
      },
      calls: []
    )
    transport = RecordingTransport.new(
      responses: [
        response(301, location: "https://www.example.com/proof.txt"),
        response(200, content_type: "text/plain", body: "proof")
      ],
      calls: []
    )
    client = Shared::NetworkSafety::SafeHttpClient.new(resolver: resolver, transport: transport)

    result = client.fetch_exact(
      origin: "http://example.com",
      url: "http://example.com/proof.txt",
      allowed_content_types: [ "text/plain" ],
      approved_redirect_origins: [ "https://www.example.com" ]
    )

    assert_equal "proof", result.fetch(:body)
    assert_equal "https://www.example.com", result.fetch(:final_origin)
    assert_equal 1, result.fetch(:redirect_count)
    assert_equal [ "example.com", "www.example.com" ], resolver.calls
    assert_equal [ "93.184.216.34", "93.184.216.35" ],
      transport.calls.map { |call| call.fetch(:ip_address) }
  end

  test "rejects path-changing redirects and every unsafe or mixed DNS answer" do
    transport = RecordingTransport.new(
      responses: [ response(302, location: "https://example.com/other") ],
      calls: []
    )
    resolver = FixtureResolver.new(addresses: { "example.com" => [ "93.184.216.34" ] }, calls: [])
    client = Shared::NetworkSafety::SafeHttpClient.new(resolver: resolver, transport: transport)
    redirect = assert_raises(Shared::NetworkSafety::Error) do
      client.fetch_exact(
        origin: "https://example.com",
        url: "https://example.com/proof.txt",
        allowed_content_types: [ "text/plain" ]
      )
    end
    assert_equal "redirect_rejected", redirect.reason_code

    policy = Shared::NetworkSafety::AddressPolicy.new
    %w[
      127.0.0.1 169.254.169.254 10.0.0.1 ::1 ::ffff:127.0.0.1
      64:ff9b::a00:1 2001:db8::1 fec0::1
    ].each do |address|
      assert_raises(Shared::NetworkSafety::Error, address) do
        policy.approve!(host: "example.com", port: 443, addresses: [ address ])
      end
    end
    assert_raises(Shared::NetworkSafety::Error) do
      policy.approve!(
        host: "example.com", port: 443, addresses: [ "93.184.216.34", "127.0.0.1" ]
      )
    end
    assert_equal [ "93.184.216.34" ],
      policy.approve!(host: "example.com", port: 443, addresses: [ "93.184.216.34" ])
  end

  private

  def fixture_client(max_response_bytes: 4096, max_redirects: 2)
    Shared::NetworkSafety::SafeHttpClient.new(
      resolver: @resolver,
      address_policy: FixtureAddressPolicy.new(fixture_host: @host),
      open_timeout: 1,
      read_timeout: 1,
      max_response_bytes: max_response_bytes,
      max_redirects: max_redirects
    )
  end

  def response(status, location: nil, content_type: nil, body: "")
    Shared::NetworkSafety::TransportResponse.new(
      status: status,
      headers: { "location" => location, "content-type" => content_type }.compact,
      body: body
    )
  end
end
