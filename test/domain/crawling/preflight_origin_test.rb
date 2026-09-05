# frozen_string_literal: true

require "test_helper"

class CrawlingPreflightOriginTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:response, :error, :request, keyword_init: true) do
    def fetch_exact(**attributes)
      self.request = attributes
      raise error if error

      response
    end
  end

  Environment = Data.define(:id, :origin)

  setup do
    @now = Time.utc(2026, 9, 5, 10)
    @origin = Properties::Public.canonical_origin(origin: "https://public.example.com")
    @environment = Environment.new(SecureRandom.uuid, @origin)
  end

  test "performs one exact-origin bounded reachability request and stores only safe evidence" do
    client = FakeClient.new(response: {
      status: 204,
      body: "ignored",
      final_origin: @origin.origin,
      final_url: "#{@origin.origin}/",
      redirect_count: 0
    })

    result = Crawling::PreflightOrigin.new(client: client, clock: -> { @now }).call(
      environment: @environment
    )

    assert_equal 204, result.status_code
    assert_equal @now, result.checked_at
    assert_equal Digest::SHA256.hexdigest(@origin.origin), result.destination_digest
    assert_equal "#{@origin.origin}/", client.request.fetch(:url)
    assert_equal [], client.request.fetch(:approved_redirect_origins)
    refute_respond_to result, :body
    refute_includes result.inspect, "ignored"
  end

  test "maps private destinations and cross-origin redirects to a stable unsafe contract" do
    %w[unsafe_destination redirect_rejected redirect_limit].each do |reason|
      client = FakeClient.new(error: Shared::Public::NetworkSafetyError.new(reason_code: reason))

      error = assert_raises(Crawling::TargetUnsafe) do
        Crawling::PreflightOrigin.new(client: client).call(environment: @environment)
      end

      assert_equal "unsafe_target", error.definition.public_code
    end
  end

  test "maps transport and server failures to a retryable unavailable contract" do
    client = FakeClient.new(error: Shared::Public::NetworkSafetyError.new(reason_code: "timeout"))
    error = assert_raises(Crawling::TargetUnavailable) do
      Crawling::PreflightOrigin.new(client: client).call(environment: @environment)
    end
    assert error.definition.retryable

    server = FakeClient.new(response: {
      status: 503,
      final_origin: @origin.origin,
      redirect_count: 0
    })
    assert_raises(Crawling::TargetUnavailable) do
      Crawling::PreflightOrigin.new(client: server).call(environment: @environment)
    end
  end
end
