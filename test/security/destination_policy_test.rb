# frozen_string_literal: true

require "test_helper"

class DestinationPolicyTest < ActiveSupport::TestCase
  FixtureResolver = Struct.new(:answers, :calls, keyword_init: true) do
    def resolve(host:)
      calls << host
      value = answers.fetch(host)
      value.respond_to?(:call) ? value.call : value
    end
  end

  Recorder = Struct.new(:events, keyword_init: true) do
    def call(**attributes)
      events << attributes
    end
  end

  Emitter = Struct.new(:events, keyword_init: true) do
    def emit(event_name, **attributes)
      events << { event_name: event_name }.merge(attributes)
    end
  end

  test "canonicalizes IDNA and a terminal dot before returning the approved IP set and port" do
    resolver = FixtureResolver.new(
      answers: { "xn--fa-hia.de" => [ "93.184.216.34", "2606:4700:4700::1111" ] },
      calls: []
    )
    recorder = Recorder.new(events: [])
    destination = policy(resolver:, recorder:).authorize!(url: "HTTPS://faß.de.:443/path?q=1")

    assert_equal "https://xn--fa-hia.de/path?q=1", destination.target.url
    assert_equal "xn--fa-hia.de", destination.target.host
    assert_equal 443, destination.port
    assert_equal [ "93.184.216.34", "2606:4700:4700::1111" ], destination.ip_addresses
    assert_equal "93.184.216.34", destination.connection_ip
    assert_equal [ "xn--fa-hia.de" ], resolver.calls
    assert_equal({
      address_count: 2,
      ipv4_address_count: 1,
      ipv6_address_count: 1,
      destination_port: 443,
      address_policy_version: Shared::NetworkSafety::AddressPolicy::POLICY_VERSION
    }, destination.provenance.as_json)
    assert_equal "succeeded", recorder.events.sole.fetch(:outcome)
    refute_match(/faß|xn--|93\.184|2606:/, recorder.events.inspect)
  end

  test "rejects ambiguous URL and hostname representations before DNS" do
    resolver = FixtureResolver.new(answers: {}, calls: [])
    recorder = Recorder.new(events: [])
    destination_policy = policy(resolver:, recorder:)
    hostile_urls = [
      "ftp://example.com/",
      "file:///etc/passwd",
      "http://user:secret@example.com/",
      "http://example.com/#fragment",
      "http://127.0.0.1/",
      "http://127.1/",
      "http://2130706433/",
      "http://0x7f000001/",
      "http://0177.0.0.1/",
      "http://0x7f.0.0.1/",
      "http://[::ffff:127.0.0.1]/",
      "http://[fe80::1%25eth0]/",
      "http://example.com../",
      "http://%31%32%37.0.0.1/",
      "http://localhost/",
      " http://example.com/",
      "http://example.com\\@127.0.0.1/"
    ]

    hostile_urls.each do |url|
      error = assert_raises(Shared::NetworkSafety::Error, url) do
        destination_policy.authorize!(url: url)
      end
      assert_equal "unsafe_destination", error.reason_code, url
      assert_equal "url_parse", error.evidence.fetch(:denial_stage), url
    end

    assert_empty resolver.calls
    assert_equal hostile_urls.length, recorder.events.length
    refute_match(/secret|127\.0\.0\.1|169\.254/, recorder.events.inspect)
  end

  test "rejects a disallowed port before DNS" do
    resolver = FixtureResolver.new(answers: {}, calls: [])

    error = assert_raises(Shared::NetworkSafety::Error) do
      policy(resolver:).authorize!(url: "https://example.com:8443/")
    end

    assert_equal "port_policy", error.evidence.fetch(:denial_stage)
    assert_equal 8443, error.evidence.fetch(:destination_port)
    assert_empty resolver.calls
  end

  test "rejects a forged or absent target before resolution" do
    resolver = FixtureResolver.new(answers: {}, calls: [])
    destination_policy = policy(resolver: resolver)

    [ nil, Object.new, "https://example.com/" ].each do |target|
      error = assert_raises(Shared::NetworkSafety::Error) do
        destination_policy.authorize_target!(target: target)
      end
      assert_equal "unsafe_destination", error.reason_code
      assert_equal "url_parse", error.evidence.fetch(:denial_stage)
    end

    assert_empty resolver.calls
  end

  test "rejects every IANA non-public IPv4 class including mapped forms" do
    address_policy = Shared::NetworkSafety::AddressPolicy.new
    blocked = %w[
      0.0.0.0 0.255.255.255 10.0.0.1 100.64.0.1 127.255.255.254
      169.254.169.254 172.16.0.1 172.31.255.255 192.0.0.1 192.0.2.1
      192.88.99.2 192.168.255.255 198.18.0.1 198.51.100.1 203.0.113.1
      224.0.0.1 239.255.255.255 240.0.0.1 255.255.255.255
      ::ffff:0.0.0.0 ::ffff:10.0.0.1 ::ffff:127.0.0.1 ::ffff:169.254.169.254
    ]

    blocked.each do |address|
      error = assert_raises(Shared::NetworkSafety::Error, address) do
        address_policy.approve!(host: "example.com", port: 443, addresses: [ address ])
      end
      assert_equal "address_policy", error.evidence.fetch(:denial_stage), address
    end

    assert_equal [ "8.8.8.8", "192.0.0.9", "192.0.0.10", "192.31.196.1", "192.52.193.1", "192.175.48.1" ],
      address_policy.approve!(
        host: "example.com",
        port: 443,
        addresses: [
          "8.8.8.8", "192.0.0.9", "192.0.0.10", "192.31.196.1", "192.52.193.1", "192.175.48.1"
        ]
      )
    assert_equal [ "8.8.8.8" ],
      address_policy.approve!(host: "example.com", port: 443, addresses: [ "::ffff:8.8.8.8" ])
  end

  test "rejects non-global IPv6 classes translations documentation and malformed addresses" do
    address_policy = Shared::NetworkSafety::AddressPolicy.new
    blocked = %w[
      :: ::1 ::192.0.2.1 64:ff9b::808:808 64:ff9b:1::1 100::1 100:0:0:1::1
      2001::1 2001:2::1 2001:db8::1 2002::1 3fff::1 5f00::1 fc00::1
      fdff:ffff::1 fe80::1 fec0::1 ff02::1
    ]

    blocked.each do |address|
      assert_raises(Shared::NetworkSafety::Error, address) do
        address_policy.approve!(host: "example.com", port: 443, addresses: [ address ])
      end
    end
    %w[fe80::1%eth0 2130706433 0177.0.0.1 0x7f000001 not-an-address].each do |address|
      error = assert_raises(Shared::NetworkSafety::Error, address) do
        address_policy.approve!(host: "example.com", port: 443, addresses: [ address ])
      end
      assert_equal "address_parse", error.evidence.fetch(:denial_stage), address
    end

    assert_equal [
      "2001:1::1", "2001:3::1", "2001:4:112::1", "2001:20::1", "2001:30::1",
      "2606:4700:4700::1111", "2620:4f:8000::1"
    ],
      address_policy.approve!(
        host: "example.com",
        port: 443,
        addresses: [
          "2001:1::1", "2001:3::1", "2001:4:112::1", "2001:20::1", "2001:30::1",
          "2606:4700:4700::1111", "2620:4f:8000::1"
        ]
      )
  end

  test "rejects the complete DNS result when any answer is unsafe and retains only bounded provenance" do
    recorder = Recorder.new(events: [])
    resolver = FixtureResolver.new(
      answers: { "mixed.example" => [ "93.184.216.34", "169.254.169.254" ] },
      calls: []
    )

    error = assert_raises(Shared::NetworkSafety::Error) do
      policy(resolver:, recorder:).authorize!(url: "https://mixed.example/")
    end

    assert_equal "unsafe_destination", error.reason_code
    assert_equal "address_policy", error.evidence.fetch(:denial_stage)
    assert_equal 2, error.evidence.fetch(:address_count)
    assert_equal 2, error.evidence.fetch(:ipv4_address_count)
    assert_equal 0, error.evidence.fetch(:ipv6_address_count)
    assert_equal 443, error.evidence.fetch(:destination_port)
    assert_equal Shared::NetworkSafety::AddressPolicy::POLICY_VERSION,
      error.evidence.fetch(:address_policy_version)
    refute_match(/mixed\.example|93\.184|169\.254/, recorder.events.inspect)
  end

  test "structured denial recorder emits only a stable reason and bounded resolution facts" do
    emitter = Emitter.new(events: [])
    recorder = Shared::NetworkSafety::DestinationDecisionRecorder.new(emitter: emitter)

    recorder.call(
      outcome: "denied",
      reason_code: "unsafe_destination",
      evidence: {
        denial_stage: "address_policy",
        address_count: 2,
        ipv4_address_count: 1,
        ipv6_address_count: 1,
        destination_port: 443,
        address_policy_version: Shared::NetworkSafety::AddressPolicy::POLICY_VERSION,
        hostname: "secret.internal",
        addresses: [ "10.0.0.1", "fd00::1" ]
      }
    )

    event = emitter.events.sole
    assert_equal "crawler.destination_rejected", event.fetch(:event_name)
    assert_equal "denied", event.fetch(:outcome)
    assert_equal "address_policy", event.fetch(:operation)
    assert_equal "unsafe_destination", event.fetch(:reason_code)
    assert_equal 2, event.fetch(:address_count)
    assert_equal 1, event.fetch(:ipv4_address_count)
    assert_equal 1, event.fetch(:ipv6_address_count)
    assert_equal 443, event.fetch(:destination_port)
    refute_match(/secret|10\.0\.0\.1|fd00/, event.inspect)
  end

  test "property corpus rejects randomized private and reserved IPv4 values" do
    random = Random.new(68_068)
    address_policy = Shared::NetworkSafety::AddressPolicy.new
    generators = [
      -> { "10.#{random.rand(256)}.#{random.rand(256)}.#{random.rand(256)}" },
      -> { "127.#{random.rand(256)}.#{random.rand(256)}.#{random.rand(256)}" },
      -> { "169.254.#{random.rand(256)}.#{random.rand(256)}" },
      -> { "172.#{random.rand(16..31)}.#{random.rand(256)}.#{random.rand(256)}" },
      -> { "192.168.#{random.rand(256)}.#{random.rand(256)}" },
      -> { "198.#{random.rand(18..19)}.#{random.rand(256)}.#{random.rand(256)}" },
      -> { "#{random.rand(224..255)}.#{random.rand(256)}.#{random.rand(256)}.#{random.rand(256)}" }
    ]

    350.times do |index|
      address = generators.fetch(index % generators.length).call
      assert_raises(Shared::NetworkSafety::Error, address) do
        address_policy.approve!(host: "fuzz.example", port: 80, addresses: [ address ])
      end
    end
  end

  private

  def policy(resolver:, recorder: Recorder.new(events: []))
    Shared::NetworkSafety::DestinationPolicy.new(resolver: resolver, recorder: recorder)
  end
end
