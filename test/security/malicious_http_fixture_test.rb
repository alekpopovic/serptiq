# frozen_string_literal: true

require "net/http"
require "test_helper"

class MaliciousHttpFixtureTest < ActiveSupport::TestCase
  setup do
    @fixture = TestSupport::Network::MaliciousHttpFixture.new.start
  end

  teardown do
    @fixture.stop
  end

  test "binds only to loopback and records bounded local requests" do
    response = local_get("/")

    assert_equal "127.0.0.1", @fixture.host
    assert_equal "local fixture", response.body
    assert_equal 1, @fixture.request_count
    assert_equal({ method: "GET", path: "/" }, @fixture.requests.pop)
  end

  test "simulates a redirect to cloud metadata without following it" do
    response = local_get("/redirect-private")

    assert_equal "302", response.code
    assert_equal "http://169.254.169.254/latest/meta-data", response.fetch("location")
    assert_equal 1, @fixture.request_count
  end

  test "provides bounded oversized and malformed payload cases" do
    oversized = local_get("/oversized")
    malformed = local_get("/malformed")

    assert_equal 64.kilobytes, oversized.body.bytesize
    assert_equal "<broken>", malformed.body
    assert_equal "application/xml", malformed.content_type
  end

  test "local DNS fixture returns both A and AAAA answers without external traffic" do
    dns = TestSupport::Network::MaliciousDnsFixture.new
      .script(host: "dual.example", type: :a, responses: [ [ "93.184.216.34" ] ])
      .script(host: "dual.example", type: :aaaa, responses: [ [ "2606:4700:4700::1111" ] ])
      .start

    addresses = dns.resolver.resolve(host: "dual.example")

    assert_equal [ "93.184.216.34", "2606:4700:4700::1111" ], addresses
    assert_equal [
      { host: "dual.example", type: :a },
      { host: "dual.example", type: :aaaa }
    ], 2.times.map { dns.requests.pop }
  ensure
    dns&.stop
  end

  test "local DNS fixture simulates public-to-private rebinding across resolutions" do
    dns = TestSupport::Network::MaliciousDnsFixture.new
      .script(
        host: "rebind.example",
        type: :a,
        responses: [ [ "93.184.216.34" ], [ "169.254.169.254" ] ]
      )
      .script(host: "rebind.example", type: :aaaa, responses: [ [] ])
      .start
    policy = Shared::NetworkSafety::DestinationPolicy.new(resolver: dns.resolver)

    first = policy.authorize!(url: "https://rebind.example/")
    error = assert_raises(Shared::NetworkSafety::Error) do
      policy.authorize!(url: "https://rebind.example/")
    end

    assert_equal [ "93.184.216.34" ], first.ip_addresses
    assert_equal "unsafe_destination", error.reason_code
    assert_equal "address_policy", error.evidence.fetch(:denial_stage)
  ensure
    dns&.stop
  end

  test "local DNS fixture proves resolver answer caps before destination approval" do
    answers = 17.times.map { |index| "8.8.8.#{index + 1}" }
    dns = TestSupport::Network::MaliciousDnsFixture.new
      .script(host: "wide.example", type: :a, responses: [ answers ])
      .script(host: "wide.example", type: :aaaa, responses: [ [] ])
      .start

    error = assert_raises(Shared::NetworkSafety::Error) do
      dns.resolver.resolve(host: "wide.example")
    end

    assert_equal "unsafe_destination", error.reason_code
    assert_equal "dns_resolution", error.evidence.fetch(:denial_stage)
    assert_equal Shared::NetworkSafety::PublicResolver::MAX_ADDRESSES,
      error.evidence.fetch(:address_count)
  ensure
    dns&.stop
  end

  private

  def local_get(path)
    client = Net::HTTP.new(@fixture.host, @fixture.port, nil)
    client.open_timeout = 1
    client.read_timeout = 1
    client.get(path)
  end
end
