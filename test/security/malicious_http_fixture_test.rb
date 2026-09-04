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

  private

  def local_get(path)
    client = Net::HTTP.new(@fixture.host, @fixture.port, nil)
    client.open_timeout = 1
    client.read_timeout = 1
    client.get(path)
  end
end
