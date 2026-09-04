# frozen_string_literal: true

require "test_helper"

class LemonSqueezyNetHttpTransportTest < ActiveSupport::TestCase
  class FakeResponse
    def initialize(body:, headers: {})
      @body = body
      @headers = headers
    end

    def code
      "200"
    end

    def each_header
      @headers.each
    end

    def [](key)
      @headers[key]
    end

    def read_body
      yield @body
    end
  end

  class FakeHttp
    attr_accessor :use_ssl, :verify_mode, :open_timeout, :read_timeout, :write_timeout, :max_retries
    attr_reader :captured_request

    def initialize(response)
      @response = response
    end

    def start
      yield self
    end

    def request(value)
      @captured_request = value
      yield @response
    end
  end

  test "enforces TLS peer verification all timeouts no implicit retries and bounded streaming" do
    http = FakeHttp.new(FakeResponse.new(body: "{}", headers: { "content-type" => "application/vnd.api+json" }))
    transport = Billing::LemonSqueezy::NetHttpTransport.new(http_factory: ->(_) { http })
    response = transport.call(
      method: :patch,
      uri: URI("https://api.lemonsqueezy.com/v1/subscriptions/4001"),
      headers: { "Authorization" => "Bearer sanitized" },
      body: "{}",
      open_timeout: 1.0,
      read_timeout: 2.0,
      write_timeout: 3.0,
      max_response_bytes: 64
    )

    assert http.use_ssl
    assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode
    assert_equal 1.0, http.open_timeout
    assert_equal 2.0, http.read_timeout
    assert_equal 3.0, http.write_timeout
    assert_equal 0, http.max_retries
    assert_instance_of Net::HTTP::Patch, http.captured_request
    assert_equal 200, response.status

    oversized = FakeHttp.new(FakeResponse.new(body: "x" * 65))
    assert_raises(Billing::LemonSqueezy::ResponseTooLarge) do
      Billing::LemonSqueezy::NetHttpTransport.new(http_factory: ->(_) { oversized }).call(
        method: :get,
        uri: URI("https://api.lemonsqueezy.com/v1/subscriptions/4001"),
        headers: {},
        body: nil,
        open_timeout: 1.0,
        read_timeout: 2.0,
        write_timeout: 3.0,
        max_response_bytes: 64
      )
    end
  end
end
