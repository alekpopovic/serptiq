# frozen_string_literal: true

require "test_helper"

class IdentityHttpClientTest < ActiveSupport::TestCase
  class ScriptedTransport
    attr_reader :calls

    def initialize(*responses)
      @responses = responses
      @calls = []
    end

    def call(**request)
      calls << request
      response = @responses.shift
      raise "unexpected transport call" unless response
      raise response if response.is_a?(Exception)

      response
    end
  end

  test "accepts only bounded JSON objects from an exact allowlisted HTTPS endpoint" do
    transport = ScriptedTransport.new(response(body: '{"subject":"stable-id"}'))
    client = build_client(transport)

    result = client.get_json(uri: allowed_endpoint, operation: "userinfo")

    assert_equal({ "subject" => "stable-id" }, result)
    assert_predicate result, :frozen?
    assert_equal 1, transport.calls.size
    assert_equal 1.0, transport.calls.first.fetch(:open_timeout)
    assert_equal 2.0, transport.calls.first.fetch(:read_timeout)
    assert_equal 128, transport.calls.first.fetch(:max_response_bytes)
  end

  test "rejects non-JSON content malformed JSON arrays and oversized bodies" do
    cases = [
      response(headers: { "content-type" => "text/html" }, body: token_body),
      response(body: "{malformed-#{sensitive_token}"),
      response(body: "[\"#{sensitive_token}\"]"),
      response(body: "{\"value\":\"#{'x' * 150}\"}")
    ]

    cases.each do |provider_response|
      error = assert_raises(Identity::ProviderError) do
        build_client(ScriptedTransport.new(provider_response)).get_json(
          uri: allowed_endpoint,
          operation: "userinfo"
        )
      end
      assert_equal "malformed_response", error.category
      assert_redacted_error(error)
    end
  end

  test "accepts only bounded arrays of JSON objects when explicitly requested" do
    transport = ScriptedTransport.new(response(body: '[{"email":"one@example.test"}]'))
    result = build_client(transport).get_json_array(
      uri: allowed_endpoint,
      operation: "email_lookup",
      max_items: 2
    )

    assert_equal [ { "email" => "one@example.test" } ], result
    assert_predicate result, :frozen?
    assert_predicate result.first, :frozen?

    excessive = ScriptedTransport.new(response(body: "[{},{}]"))
    assert_raises(Identity::ProviderError) do
      build_client(excessive).get_json_array(uri: allowed_endpoint, operation: "email_lookup", max_items: 1)
    end
    assert_raises(ArgumentError) do
      build_client(ScriptedTransport.new).get_json_array(
        uri: allowed_endpoint, operation: "email_lookup", max_items: 101
      )
    end
  end

  test "maps timeout response bounds provider denial and revoked credentials to safe categories" do
    cases = {
      Timeout::Error.new(sensitive_token) => "timeout",
      Identity::ResponseTooLarge.new(sensitive_token) => "malformed_response",
      response(status: 400, body: token_body) => "access_denied",
      response(status: 401, body: token_body) => "credentials_revoked",
      response(status: 403, body: token_body) => "credentials_revoked",
      response(status: 403, body: token_body,
        headers: json_headers.merge("x-ratelimit-remaining" => "0")) => "rate_limited",
      response(status: 429, body: token_body, headers: json_headers.merge("retry-after" => "30")) => "rate_limited",
      response(status: 503, body: token_body) => "unavailable"
    }

    cases.each do |provider_response, expected_category|
      error = assert_raises(Identity::ProviderError) do
        build_client(ScriptedTransport.new(provider_response)).get_json(
          uri: allowed_endpoint,
          operation: "userinfo"
        )
      end
      assert_equal expected_category, error.category
      assert_redacted_error(error)
    end
  end

  test "retries only bounded safe discovery and JWKS GET failures" do
    delays = []
    discovery_transport = ScriptedTransport.new(
      response(status: 503, body: token_body),
      response(body: '{"issuer":"https://accounts.google.com"}')
    )
    discovery = build_client(discovery_transport, sleeper: ->(delay) { delays << delay })

    result = discovery.get_json(uri: allowed_endpoint, operation: "discovery")

    assert_equal "https://accounts.google.com", result.fetch("issuer")
    assert_equal [ 0.1 ], delays
    assert_equal 2, discovery_transport.calls.size

    delays.clear
    jwks_transport = ScriptedTransport.new(
      response(status: 429, headers: json_headers.merge("retry-after" => "1")),
      response(body: '{"keys":[]}')
    )
    jwks = build_client(jwks_transport, sleeper: ->(delay) { delays << delay })

    assert_equal [], jwks.get_json(uri: allowed_endpoint, operation: "jwks").fetch("keys")
    assert_equal [ 1 ], delays
    assert_equal 2, jwks_transport.calls.size
  end

  test "does not retry long rate limits unsafe GET operations or token exchange POSTs" do
    long_limit = ScriptedTransport.new(
      response(status: 429, headers: json_headers.merge("retry-after" => "30")),
      response(body: "{}")
    )
    error = assert_raises(Identity::ProviderError) do
      build_client(long_limit).get_json(uri: allowed_endpoint, operation: "jwks")
    end
    assert_equal "rate_limited", error.category
    assert_equal 1, long_limit.calls.size

    userinfo = ScriptedTransport.new(response(status: 503), response(body: "{}"))
    assert_raises(Identity::ProviderError) do
      build_client(userinfo).get_json(uri: allowed_endpoint, operation: "userinfo")
    end
    assert_equal 1, userinfo.calls.size

    token = ScriptedTransport.new(response(status: 503, body: token_body), response(body: "{}"))
    token_error = assert_raises(Identity::ProviderError) do
      build_client(token).post_form_json(
        uri: allowed_endpoint,
        operation: "token_exchange",
        form: { code: sensitive_token, client_secret: "provider-client-secret" }
      )
    end
    assert_equal "unavailable", token_error.category
    assert_equal 1, token.calls.size
    assert_redacted_error(token_error)
  end

  test "rejects unallowlisted modified insecure and invalid endpoints before transport" do
    transport = ScriptedTransport.new(response(body: "{}"))
    client = build_client(transport)
    endpoints = [
      "https://provider-attacker.example/token",
      "http://accounts.google.com/token",
      "https://accounts.google.com/token?redirect=https://provider-attacker.example",
      "not a URI"
    ]

    endpoints.each do |endpoint|
      error = assert_raises(Identity::ProviderError) do
        client.get_json(uri: endpoint, operation: "discovery")
      end
      assert_equal "configuration", error.category
      assert_redacted_error(error)
    end
    assert_empty transport.calls
  end

  test "validates direct HTTP client limits" do
    assert_raises(ArgumentError) { build_client(ScriptedTransport.new, safe_retries: 4) }
    assert_raises(ArgumentError) { build_client(ScriptedTransport.new, max_response_bytes: 0) }
    assert_raises(ArgumentError) { build_client(ScriptedTransport.new, open_timeout: 0) }
  end

  private

  def build_client(transport, open_timeout: 1.0, read_timeout: 2.0, max_response_bytes: 128,
    safe_retries: 2, sleeper: ->(_) { })
    Identity::HttpClient.new(
      allowed_endpoints: [ allowed_endpoint ],
      open_timeout: open_timeout,
      read_timeout: read_timeout,
      max_response_bytes: max_response_bytes,
      safe_retries: safe_retries,
      transport: transport,
      sleeper: sleeper,
      clock: -> { Time.utc(2026, 9, 4, 3, 0, 0) }
    )
  end

  def response(status: 200, headers: json_headers, body: "{}")
    Identity::HttpResponse.new(status: status, headers: headers, body: body)
  end

  def json_headers
    { "content-type" => "application/json; charset=utf-8" }
  end

  def allowed_endpoint
    URI("https://accounts.google.com/token")
  end

  def token_body
    "{\"access_token\":\"#{sensitive_token}\"}"
  end

  def sensitive_token
    "provider-token-that-must-never-leak"
  end

  def assert_redacted_error(error)
    refute_includes error.message, sensitive_token
    refute_includes error.inspect, sensitive_token
    refute_includes error.full_message, sensitive_token
    refute_includes error.message, "provider-client-secret"
    refute_includes error.inspect, "provider-client-secret"
  end
end
