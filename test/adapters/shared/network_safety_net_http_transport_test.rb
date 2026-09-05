# frozen_string_literal: true

require "test_helper"

class NetworkSafetyNetHttpTransportTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :headers, :chunks, keyword_init: true) do
    def [](name)
      headers[name.to_s.downcase]
    end

    def read_body
      chunks.each { |chunk| yield chunk }
    end
  end

  class RecordingHttp
    attr_accessor :ipaddr, :use_ssl, :verify_mode, :verify_hostname, :open_timeout,
      :read_timeout, :write_timeout, :max_retries
    attr_reader :captured_request

    def initialize(response:, peer_ip:, proxy: false)
      @response = response
      @peer_ip = peer_ip
      @proxy = proxy
    end

    def proxy?
      @proxy
    end

    def use_ssl?
      use_ssl
    end

    def request(request)
      @captured_request = request
      configured_ip = ipaddr
      self.ipaddr = @peer_ip
      yield @response
    ensure
      self.ipaddr = configured_ip
    end
  end

  test "pins the approved IP while preserving the DNS host for Host SNI and certificate checks" do
    response = FakeResponse.new(
      code: "200",
      headers: { "content-type" => "text/plain", "content-length" => "2" },
      chunks: [ "ok" ]
    )
    connection = RecordingHttp.new(response: response, peer_ip: "93.184.216.34")
    factory_calls = []
    transport = Shared::NetworkSafety::NetHttpTransport.new(
      http_factory: ->(host, port) { factory_calls << [ host, port ]; connection }
    )

    result = transport.get(
      destination: destination("https://xn--fa-hia.de/path", "93.184.216.34"),
      open_timeout: 1,
      read_timeout: 2,
      max_response_bytes: 1024,
      user_agent: "SearchOpsBot/1.0"
    )

    assert_equal [ [ "xn--fa-hia.de", 443 ] ], factory_calls
    assert_equal true, connection.use_ssl
    assert_equal OpenSSL::SSL::VERIFY_PEER, connection.verify_mode
    assert_equal true, connection.verify_hostname
    assert_equal 0, connection.max_retries
    assert_equal "xn--fa-hia.de", connection.captured_request["host"]
    assert_equal "close", connection.captured_request["connection"]
    assert_equal "identity", connection.captured_request["accept-encoding"]
    assert_equal "ok", result.body
  end

  test "rejects a peer that differs from the pinned approved connection address" do
    response = FakeResponse.new(code: "200", headers: {}, chunks: [ "forbidden" ])
    connection = RecordingHttp.new(response: response, peer_ip: "127.0.0.1")
    transport = Shared::NetworkSafety::NetHttpTransport.new(http_factory: ->(*) { connection })

    error = assert_raises(Shared::NetworkSafety::Error) do
      transport.get(
        destination: destination("https://example.com/", "93.184.216.34"),
        open_timeout: 1,
        read_timeout: 1,
        max_response_bytes: 1024
      )
    end

    assert_equal "unsafe_destination", error.reason_code
    assert_equal "transport", error.evidence.fetch(:denial_stage)
  end

  test "disables proxy routing before a request can bypass the pinned destination" do
    response = FakeResponse.new(code: "200", headers: {}, chunks: [])
    connection = RecordingHttp.new(response: response, peer_ip: "93.184.216.34", proxy: true)
    transport = Shared::NetworkSafety::NetHttpTransport.new(http_factory: ->(*) { connection })

    error = assert_raises(Shared::NetworkSafety::Error) do
      transport.get(
        destination: destination("https://example.com/", "93.184.216.34"),
        open_timeout: 1,
        read_timeout: 1,
        max_response_bytes: 1024
      )
    end

    assert_equal "unsafe_destination", error.reason_code
    assert_nil connection.captured_request
  end

  test "connects to a pinned local test address while sending the canonical hostname authority" do
    fixture = TestSupport::Network::MaliciousHttpFixture.new.start
    target_url = "http://fixture.example:#{fixture.port}/"

    response = Shared::NetworkSafety::NetHttpTransport.new.get(
      destination: destination(target_url, fixture.host),
      open_timeout: 1,
      read_timeout: 1,
      max_response_bytes: 1024
    )

    assert_equal "local fixture", response.body
    assert_equal "fixture.example:#{fixture.port}", fixture.request_headers.pop.fetch("host")
    assert_equal 1, fixture.request_count
  ensure
    fixture&.stop
  end

  private

  def destination(url, address)
    target = Shared::NetworkSafety::HttpTarget.new(url: url)
    parsed = IPAddr.new(address)
    provenance = Shared::NetworkSafety::ResolutionProvenance.new(
      address_count: 1,
      ipv4_address_count: parsed.ipv4? ? 1 : 0,
      ipv6_address_count: parsed.ipv6? ? 1 : 0,
      destination_port: target.port,
      address_policy_version: Shared::NetworkSafety::AddressPolicy::POLICY_VERSION
    )
    Shared::NetworkSafety::ApprovedDestination.new(
      target: target,
      ip_addresses: [ address ],
      port: target.port,
      provenance: provenance
    )
  end
end
