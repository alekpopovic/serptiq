# frozen_string_literal: true

require "test_helper"

class IdentityNetHttpTransportTest < ActiveSupport::TestCase
  class FakeResponse
    attr_reader :code

    def initialize(code: "200", headers: {}, chunks: [])
      @code = code
      @headers = headers
      @chunks = chunks
    end

    def each_header
      @headers.each
    end

    def [](name)
      @headers[name]
    end

    def read_body
      @chunks.each { |chunk| yield chunk }
    end
  end

  class FakeConnection
    attr_accessor :use_ssl, :verify_mode, :open_timeout, :read_timeout, :write_timeout, :max_retries
    attr_reader :captured_request

    def initialize(response)
      @response = response
    end

    def start
      yield self
    end

    def request(request)
      @captured_request = request
      yield @response
    end
  end

  test "uses verified TLS bounded timeouts and disables implicit Net HTTP retries" do
    response = FakeResponse.new(
      headers: { "content-type" => "application/json", "content-length" => "11" },
      chunks: [ '{"ok":true}' ]
    )
    connection = FakeConnection.new(response)

    result = Identity::NetHttpTransport.new(http_factory: ->(_) { connection }).call(
      method: :get,
      uri: URI("https://accounts.google.com/discovery"),
      headers: { "Accept" => "application/json" },
      body: nil,
      open_timeout: 1.0,
      read_timeout: 2.0,
      max_response_bytes: 64
    )

    assert connection.use_ssl
    assert_equal OpenSSL::SSL::VERIFY_PEER, connection.verify_mode
    assert_equal 1.0, connection.open_timeout
    assert_equal 2.0, connection.read_timeout
    assert_equal 2.0, connection.write_timeout
    assert_equal 0, connection.max_retries
    assert_instance_of Net::HTTP::Get, connection.captured_request
    assert_equal '{"ok":true}', result.body
  end

  test "rejects declared and streamed responses above the byte limit" do
    declared = FakeConnection.new(FakeResponse.new(headers: { "content-length" => "65" }))
    streamed = FakeConnection.new(FakeResponse.new(chunks: [ "a" * 40, "b" * 25 ]))

    [ declared, streamed ].each do |connection|
      assert_raises(Identity::ResponseTooLarge) do
        Identity::NetHttpTransport.new(http_factory: ->(_) { connection }).call(
          method: :post,
          uri: URI("https://oauth2.googleapis.com/token"),
          headers: {},
          body: "synthetic-form",
          open_timeout: 1.0,
          read_timeout: 2.0,
          max_response_bytes: 64
        )
      end
    end
  end
end
