# frozen_string_literal: true

require "test_helper"

class PinnedHttpTransportTest < ActiveSupport::TestCase
  Sink = Struct.new(:body, :largest_chunk, keyword_init: true) do
    def write(chunk)
      self.largest_chunk = [ largest_chunk.to_i, chunk.bytesize ].max
      body << chunk
    end

    def finish = body.freeze
    def abort = body.clear
  end

  setup do
    @fixture = TestSupport::Network::MaliciousHttpFixture.new.start
    @transport = Shared::NetworkSafety::PinnedHttpTransport.new
  end

  teardown { @fixture.stop }

  test "performs bounded GET and HEAD against only the pinned connection plan" do
    get_sink = sink
    get_response = request("/", sink: get_sink)
    head_sink = sink
    head_response = request("/", method: :head, sink: head_sink)

    assert_equal 200, get_response.status
    assert_equal "local fixture", get_sink.body
    assert_equal Digest::SHA256.hexdigest("local fixture"), get_response.body_sha256
    assert_equal 0, head_response.decoded_bytes
    assert_empty head_sink.body
    assert_equal %w[GET HEAD], 2.times.map { @fixture.requests.pop.fetch(:method) }
    headers = 2.times.map { @fixture.request_headers.pop }
    assert headers.all? { |item| item.fetch("host") == "fixture.example:#{@fixture.port}" }
    assert headers.all? { |item| item.fetch("user-agent") == "SearchOpsBot/1.0 (+https://searchops.test/crawler)" }
    assert headers.all? { |item| item.fetch("accept-encoding") == "gzip, deflate, identity" }
  end

  test "streams and hashes decoded gzip without retaining an unbounded transport body" do
    output = sink
    response = request("/gzip", sink: output)

    assert_equal "compressed fixture body", output.body
    assert_equal output.body.bytesize, response.decoded_bytes
    assert_operator response.compressed_bytes, :>, 0
    assert_equal "gzip", response.headers.fetch("content-encoding")
    assert_equal Digest::SHA256.hexdigest(output.body), response.body_sha256
    assert_operator output.largest_chunk, :<=, Shared::NetworkSafety::PinnedHttpTransport::READ_CHUNK_BYTES
  end

  test "streams deflate and chunked bodies without trusting a chunk length as a buffer size" do
    deflated = sink
    deflate_response = request("/deflate", sink: deflated)
    chunked = sink
    chunked_response = request("/chunked", sink: chunked)

    assert_equal "deflated fixture body", deflated.body
    assert_equal "deflate", deflate_response.headers.fetch("content-encoding")
    assert_equal "chunked fixture body", chunked.body
    assert_equal chunked.body.bytesize, chunked_response.decoded_bytes

    error = assert_raises(Shared::NetworkSafety::Error) do
      request("/oversized-chunk", limits: limits(max_body_bytes: 1024))
    end
    assert_equal "response_too_large", error.reason_code
  end

  test "rejects headers compressed bodies decoded bombs and unsupported encodings at their own limits" do
    cases = {
      "/oversized-header" => [ limits(max_header_bytes: 1024), "header_too_large" ],
      "/oversized" => [ limits(max_body_bytes: 1024), "response_too_large" ],
      "/gzip-bomb" => [
        limits(max_body_bytes: 64.kilobytes, max_decompressed_bytes: 256.kilobytes,
          max_decompression_ratio: 10),
        "decompression_limit"
      ],
      "/unsupported-encoding" => [ limits, "unsupported_content_encoding" ]
    }

    cases.each do |path, (request_limits, reason)|
      output = sink
      error = assert_raises(Shared::NetworkSafety::Error, path) do
        request(path, sink: output, limits: request_limits)
      end
      assert_equal reason, error.reason_code, path
      assert_empty output.body, path if reason.in?(%w[header_too_large response_too_large unsupported_content_encoding])
    end


    decoded_error = assert_raises(Shared::NetworkSafety::Error) do
      request(
        "/gzip-bomb",
        limits: limits(max_decompressed_bytes: 64.kilobytes, max_decompression_ratio: 1000)
      )
    end
    assert_equal "decompression_limit", decoded_error.reason_code

    malformed = assert_raises(Shared::NetworkSafety::Error) { request("/malformed-gzip") }
    assert_equal "malformed_response", malformed.reason_code
  end

  test "enforces absolute header and body deadlines against slowloris responses" do
    header_error = assert_raises(Shared::NetworkSafety::Error) do
      request("/slow-headers", limits: limits(header_timeout: 0.1))
    end
    assert_equal "header_timeout", header_error.reason_code

    body_error = assert_raises(Shared::NetworkSafety::Error) do
      request("/slow-body", limits: limits(body_timeout: 0.1))
    end
    assert_equal "body_timeout", body_error.reason_code
  end

  test "the total deadline wins over a longer stage deadline" do
    error = assert_raises(Shared::NetworkSafety::Error) do
      request("/slow-headers", limits: limits(header_timeout: 1, total_timeout: 0.1))
    end

    assert_equal "total_timeout", error.reason_code
  end

  test "interrupts a slow body when scan cancellation is observed" do
    canceled = false
    trigger = Thread.new do
      sleep 0.03
      canceled = true
    end
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    error = assert_raises(Shared::NetworkSafety::Error) do
      request("/slow-body", cancellation: -> { canceled })
    end

    assert_equal "canceled", error.reason_code
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 0.22
  ensure
    trigger&.join
  end

  test "checks cancellation before opening the approved connection" do
    error = assert_raises(Shared::NetworkSafety::Error) do
      request("/", cancellation: -> { true })
    end

    assert_equal "canceled", error.reason_code
    assert_equal 0, @fixture.request_count
  end

  test "categorizes connect deadline failures and total deadline precedence" do
    transport = Shared::NetworkSafety::PinnedHttpTransport.new(
      socket_factory: ->(*) { raise Errno::ETIMEDOUT }
    )

    connect_error = assert_raises(Shared::NetworkSafety::Error) do
      request_with(transport, "/", limits: limits(connect_timeout: 0.1, total_timeout: 1))
    end
    total_error = assert_raises(Shared::NetworkSafety::Error) do
      request_with(transport, "/", limits: limits(connect_timeout: 1, total_timeout: 0.1))
    end

    assert_equal "connect_timeout", connect_error.reason_code
    assert_equal "total_timeout", total_error.reason_code
  end

  test "rejects untrusted and wrong-host certificates while accepting a locally trusted exact hostname" do
    tls = TestSupport::Network::MaliciousTlsFixture.new.start
    destination = destination_for("https://fixture.example:#{tls.port}/", tls.host)

    untrusted = assert_raises(Shared::NetworkSafety::Error) do
      @transport.request(
        destination: destination,
        method: :get,
        limits: limits,
        user_agent: user_agent,
        sink: sink
      )
    end
    assert_equal "tls_certificate", untrusted.reason_code

    trusted_transport = Shared::NetworkSafety::PinnedHttpTransport.new(
      ssl_context_factory: -> {
        context = OpenSSL::SSL::SSLContext.new
        context.cert_store = tls.certificate_store
        context
      }
    )
    output = sink
    trusted = trusted_transport.request(
      destination: destination,
      method: :get,
      limits: limits,
      user_agent: user_agent,
      sink: output
    )
    assert_equal "verified tls fixture", output.body
    assert_operator trusted.timings.fetch(:tls_ms), :>=, 0

    wrong_host = assert_raises(Shared::NetworkSafety::Error) do
      trusted_transport.request(
        destination: destination_for("https://other.example:#{tls.port}/", tls.host),
        method: :get,
        limits: limits,
        user_agent: user_agent,
        sink: sink
      )
    end
    assert_equal "tls_certificate", wrong_host.reason_code
  ensure
    tls&.stop
  end

  test "streams a bounded large response in fixed-size chunks" do
    output = sink
    response = request(
      "/oversized",
      sink: output,
      limits: limits(max_body_bytes: 64.kilobytes, max_decompressed_bytes: 64.kilobytes)
    )

    assert_equal 64.kilobytes, response.decoded_bytes
    assert_equal 64.kilobytes, output.body.bytesize
    assert_operator output.largest_chunk, :<=, 16.kilobytes
  end

  private

  def request(path, method: :get, sink: sink(), limits: limits(), cancellation: -> { false })
    request_with(@transport, path, method: method, sink: sink, limits: limits, cancellation: cancellation)
  end

  def request_with(transport, path, method: :get, sink: sink(), limits: limits(), cancellation: -> { false })
    transport.request(
      destination: destination_for("http://fixture.example:#{@fixture.port}#{path}", @fixture.host),
      method: method,
      limits: limits,
      user_agent: user_agent,
      sink: sink,
      cancellation: cancellation
    )
  end

  def user_agent
    "SearchOpsBot/1.0 (+https://searchops.test/crawler)"
  end

  def sink
    Sink.new(body: +"".b, largest_chunk: 0)
  end

  def limits(**overrides)
    Shared::NetworkSafety::TransportLimits.new(**{
      connect_timeout: 1,
      tls_timeout: 1,
      header_timeout: 1,
      body_timeout: 1,
      total_timeout: 3,
      max_header_bytes: 8192,
      max_body_bytes: 128.kilobytes,
      max_decompressed_bytes: 256.kilobytes,
      max_decompression_ratio: 100
    }.merge(overrides))
  end

  def destination_for(url, address)
    target = Shared::NetworkSafety::HttpTarget.new(url: url)
    provenance = Shared::NetworkSafety::ResolutionProvenance.new(
      address_count: 1,
      ipv4_address_count: 1,
      ipv6_address_count: 0,
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
