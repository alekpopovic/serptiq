# frozen_string_literal: true

require "test_helper"

class CrawlingHttpFetcherTest < ActiveSupport::TestCase
  Resolver = Struct.new(:addresses, :calls, keyword_init: true) do
    def resolve(host:)
      calls << host
      addresses.fetch(host)
    end
  end

  class Sink
    attr_reader :body

    def initialize
      @body = +"".b
    end

    def write(chunk)
      @body << chunk
    end

    def finish
      @body.dup.freeze
    end

    def abort
      @body.clear
    end
  end

  class ScriptedTransport
    attr_reader :calls

    def initialize(*script)
      @script = script
      @calls = []
    end

    def request(**attributes)
      @calls << attributes.except(:sink, :cancellation)
      value = @script.shift
      raise "unexpected HTTP transport request" unless value
      raise value if value.is_a?(Exception)

      response, body = value
      attributes.fetch(:sink).write(body)
      response
    end
  end

  Recorder = Struct.new(:results, keyword_init: true) do
    def call(result)
      results << result
    end
  end

  setup do
    @resolver = Resolver.new(
      addresses: {
        "example.com" => [ "93.184.216.34" ],
        "www.example.com" => [ "93.184.216.35" ]
      },
      calls: []
    )
  end

  test "normalizes successful GET metadata and streams the artifact through the caller sink" do
    body = "<!doctype html><html lang='en'></html>"
    transport = ScriptedTransport.new(scripted_response(
      body: body,
      headers: {
        "content-type" => "Text/HTML; Charset=\"UTF-8\"",
        "content-encoding" => "identity",
        "set-cookie" => "session=must-not-survive"
      },
      sniffed_kind: "html"
    ))
    sinks = []
    recorder = Recorder.new(results: [])
    result = fetcher(transport, recorder: recorder).call(
      url: "https://example.com/page",
      sink_factory: -> { Sink.new.tap { |sink| sinks << sink } },
      contact_url: "https://searchops.test/crawler"
    )

    assert result.successful?
    assert_equal "text/html", result.media_type
    assert_equal "utf-8", result.charset
    assert_equal body, result.artifact
    assert_equal Digest::SHA256.hexdigest(body), result.body_sha256
    assert_equal({ "content-type" => "Text/HTML; Charset=\"UTF-8\"" }, result.response_headers)
    assert_equal 1, result.request_count
    assert_equal "response", result.hops.sole.outcome
    assert_same result, recorder.results.sole
    assert_equal :get, transport.calls.sole.fetch(:method)
    assert_equal "SearchOpsBot/1.0 (+https://searchops.test/crawler)",
      transport.calls.sole.fetch(:user_agent)
    refute_match(/example\.com|93\.184/, result.inspect)
  end

  test "supports HEAD without a response artifact body" do
    transport = ScriptedTransport.new(scripted_response(body: "", status: 204, sniffed_kind: "empty"))

    result = fetcher(transport).call(url: "https://example.com/page", method: :head)

    assert result.successful?
    assert_equal "HEAD", result.method
    assert_nil result.artifact
    assert_equal :head, transport.calls.sole.fetch(:method)
  end

  test "rejects non-idempotent methods before resolution or transport" do
    transport = ScriptedTransport.new(scripted_response(body: "forbidden"))

    error = assert_raises(ArgumentError) do
      fetcher(transport).call(url: "https://example.com/page", method: :post)
    end

    assert_equal "HTTP fetch request is invalid", error.message
    assert_empty transport.calls
    assert_empty @resolver.calls

    assert_raises(ArgumentError) do
      fetcher(transport).call(
        url: "https://example.com/page",
        approved_redirect_origins: [ "https://www.example.com/not-an-origin" ]
      )
    end
    assert_empty transport.calls
    assert_empty @resolver.calls
  end

  test "manually follows only approved redirects and records canonical hop provenance" do
    transport = ScriptedTransport.new(
      scripted_response(status: 301, headers: { "location" => "https://www.example.com/final" }),
      scripted_response(body: "done")
    )
    sinks = []
    result = fetcher(transport).call(
      url: "https://example.com/start",
      approved_redirect_origins: %w[https://example.com https://www.example.com],
      sink_factory: -> { Sink.new.tap { |sink| sinks << sink } }
    )

    assert result.successful?
    assert_equal "https://www.example.com/final", result.final_url
    assert_equal 1, result.redirect_count
    assert_equal 2, result.request_count
    assert_equal %w[redirect response], result.hops.map(&:outcome)
    assert_equal "https://www.example.com/final", result.hops.first.location_url
    assert_equal %w[example.com www.example.com], @resolver.calls
    assert_empty sinks.first.body
    assert_equal "done", result.artifact
  end

  test "rejects credential scheme origin and redirect-loop violations before another resolution" do
    locations = [
      "ftp://outside.example/file",
      "https://user:secret@outside.example/file",
      "https://outside.example/file"
    ]
    locations.each do |location|
      @resolver.calls.clear
      transport = ScriptedTransport.new(scripted_response(status: 302, headers: { "location" => location }))
      result = fetcher(transport).call(url: "https://example.com/start")

      assert_equal "rejected", result.outcome, location
      assert_equal "redirect_rejected", result.failure_category, location
      assert_equal 302, result.hops.sole.status, location
      assert_nil result.hops.sole.location_url, location
      assert_equal [ "example.com" ], @resolver.calls, location
    end

    loop_transport = ScriptedTransport.new(
      scripted_response(status: 302, headers: { "location" => "/again" }),
      scripted_response(status: 302, headers: { "location" => "/again" })
    )
    looped = fetcher(loop_transport, max_redirects: 1).call(url: "https://example.com/start")
    assert_equal "redirect_limit", looped.failure_category
    assert_equal 2, looped.request_count
  end

  test "retries only bounded safe transient failures with fresh destination decisions" do
    waits = []
    transport = ScriptedTransport.new(
      Shared::NetworkSafety::Error.new(reason_code: "connect_timeout"),
      scripted_response(status: 503, headers: { "retry-after" => "1" }),
      scripted_response(body: "recovered")
    )
    result = fetcher(
      transport,
      retry_waiter: ->(delay, _cancellation) { waits << delay }
    ).call(url: "https://example.com/retry", sink_factory: -> { Sink.new })

    assert result.successful?
    assert_equal 2, result.retry_count
    assert_equal 3, result.request_count
    assert_equal %w[retry retry response], result.hops.map(&:outcome)
    assert_equal %i[get get get], transport.calls.map { |call| call.fetch(:method) }
    assert_equal 1, result.hops.first.resolution_provenance.fetch(:address_count)
    assert_equal [ 0.25, 1 ], waits
    assert_equal [ "example.com" ] * 3, @resolver.calls
  end

  test "does not retry certificate policy size encoding or malformed response failures" do
    %w[tls_certificate response_too_large unsupported_content_encoding malformed_response].each do |reason|
      @resolver.calls.clear
      transport = ScriptedTransport.new(Shared::NetworkSafety::Error.new(reason_code: reason))
      result = fetcher(transport).call(url: "https://example.com/failure")

      assert_equal reason == "tls_certificate" ? "failed" : "rejected", result.outcome, reason
      assert_equal reason, result.failure_category, reason
      assert_equal 0, result.retry_count, reason
      assert_equal 1, transport.calls.length, reason
    end
  end

  test "checks scan cancellation before requests and between bounded retries" do
    untouched = ScriptedTransport.new(scripted_response(body: "forbidden"))
    canceled = fetcher(untouched).call(
      url: "https://example.com/canceled",
      cancellation: -> { true }
    )
    assert_equal "canceled", canceled.outcome
    assert_equal "scan_canceled", canceled.failure_category
    assert_equal 0, canceled.request_count
    assert_empty untouched.calls
    assert_empty @resolver.calls

    checks = 0
    retrying = ScriptedTransport.new(Shared::NetworkSafety::Error.new(reason_code: "connect_timeout"))
    interrupted = fetcher(
      retrying,
      retry_waiter: ->(_delay, _cancellation) { checks = 2 }
    ).call(
      url: "https://example.com/canceled",
      cancellation: -> { checks += 1; checks >= 3 }
    )
    assert_equal "canceled", interrupted.outcome
    assert_equal "scan_canceled", interrupted.failure_category
    assert_equal 1, interrupted.request_count
  end

  test "rejects misleading declared media types without returning the streamed artifact" do
    transport = ScriptedTransport.new(scripted_response(
      body: "%PDF-1.7\nsynthetic",
      headers: { "content-type" => "text/html" },
      sniffed_kind: "pdf"
    ))

    result = fetcher(transport).call(
      url: "https://example.com/misleading",
      sink_factory: -> { Sink.new }
    )

    assert_equal "rejected", result.outcome
    assert_equal "content_type_mismatch", result.failure_category
    assert_nil result.artifact
  end

  test "fetch telemetry contains bounded facts and excludes targets bodies and addresses" do
    result = fetcher(ScriptedTransport.new(scripted_response(body: "private page"))).call(
      url: "https://example.com/private?token=secret",
      sink_factory: -> { Sink.new }
    )
    events = []

    recorder = Crawling::HttpFetchRecorder.new(
      emitter: ->(name, **attributes) { events << [ name, attributes ] }
    )
    recorder.call(result)

    name, attributes = events.sole
    assert_equal "crawler.http_fetch", name
    assert_equal "succeeded", attributes.fetch(:outcome)
    assert_equal "get", attributes.fetch(:operation)
    serialized = attributes.inspect
    refute_includes serialized, "example.com"
    refute_includes serialized, "private page"
    refute_includes serialized, "93.184.216.34"
  end

  private

  def fetcher(transport, recorder: Recorder.new(results: []), **options)
    Crawling::HttpFetcher.new(
      destination_policy: Shared::NetworkSafety::DestinationPolicy.new(resolver: @resolver),
      transport: transport,
      limits: limits,
      max_redirects: options.fetch(:max_redirects, 5),
      safe_retries: options.fetch(:safe_retries, 2),
      retry_base_delay: 0.25,
      retry_max_delay: 5,
      retry_waiter: options.fetch(:retry_waiter, ->(*) { }),
      recorder: recorder
    )
  end

  def limits
    Shared::NetworkSafety::TransportLimits.new(
      connect_timeout: 1,
      tls_timeout: 1,
      header_timeout: 1,
      body_timeout: 1,
      total_timeout: 10,
      max_header_bytes: 8192,
      max_body_bytes: 128.kilobytes,
      max_decompressed_bytes: 256.kilobytes,
      max_decompression_ratio: 100
    )
  end

  def scripted_response(body: "", status: 200, headers: { "content-type" => "text/plain" },
    sniffed_kind: body.empty? ? "empty" : "text")
    response = Shared::NetworkSafety::BoundedTransportResponse.new(
      status: status,
      headers: headers,
      header_bytes: 64,
      compressed_bytes: body.bytesize,
      decoded_bytes: body.bytesize,
      body_sha256: Digest::SHA256.hexdigest(body),
      sniffed_kind: sniffed_kind,
      timings: { connect_ms: 1, tls_ms: 1, header_ms: 1, body_ms: 1, total_ms: 4 }
    )
    [ response, body ]
  end
end
