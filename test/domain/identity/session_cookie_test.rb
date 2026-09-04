# frozen_string_literal: true

require "test_helper"

class IdentitySessionCookieTest < ActiveSupport::TestCase
  class RecordingCookieJar
    attr_reader :writes, :deletions

    def initialize
      @values = {}
      @writes = {}
      @deletions = {}
    end

    def [](name)
      @values[name]
    end

    def []=(name, options)
      @writes[name] = options
      @values[name] = options.fetch(:value)
    end

    def delete(name, **options)
      @deletions[name] = options
      @values.delete(name)
    end
  end

  test "protected environments use a host-only Secure HttpOnly SameSite cookie" do
    jar = RecordingCookieJar.new
    cookie = Identity::SessionCookie.new(jar, environment: "production")
    expiry = 1.day.from_now

    cookie.write(token: "opaque-token", expires_at: expiry)
    options = jar.writes.fetch("__Host-searchops_session")

    assert_equal "opaque-token", options.fetch(:value)
    assert_equal expiry, options.fetch(:expires)
    assert_equal "/", options.fetch(:path)
    assert options.fetch(:httponly)
    assert options.fetch(:secure)
    assert_equal :lax, options.fetch(:same_site)
    refute options.key?(:domain), "__Host- cookies must remain host-only"
  end

  test "development cookie keeps the same path and deletion attributes without forcing TLS" do
    jar = RecordingCookieJar.new
    cookie = Identity::SessionCookie.new(jar, environment: "development")

    cookie.write(token: "opaque-token", expires_at: 1.day.from_now)
    assert_equal "opaque-token", cookie.read
    refute jar.writes.fetch("searchops_session").fetch(:secure)

    cookie.delete
    assert_equal cookie.options, jar.deletions.fetch("searchops_session")
    assert_nil cookie.read
  end
end
