# frozen_string_literal: true

require "test_helper"

class ReleaseInformationTest < ActiveSupport::TestCase
  Settings = Struct.new(:values) do
    def fetch(key)
      values[key]
    end
  end

  test "returns only safe release provenance and runtime versions" do
    settings = Settings.new({
      release_sha: "0123456789abcdef0123456789abcdef01234567",
      build_timestamp: "2026-09-04T03:15:00+02:00",
      database_url: "postgresql://private",
      secret_key_base: "private-secret"
    })

    payload = Shared::ReleaseInformation.call(
      settings: settings,
      environment: "production",
      ruby_version: "4.0.5",
      rails_version: "8.1.3.1"
    )

    assert_equal "0123456789abcdef0123456789abcdef01234567", payload.dig(:release, :commit)
    assert_equal "2026-09-04T01:15:00Z", payload.dig(:release, :build_time)
    assert_equal({ ruby: "4.0.5", rails: "8.1.3.1" }, payload.fetch(:runtime))
    refute_match(/private|database|secret|postgresql/, payload.to_s)
  end

  test "does not echo malformed release build or runtime values" do
    settings = Settings.new({
      release_sha: "release\nSECRET_KEY_BASE=private",
      build_timestamp: "token=private"
    })

    payload = Shared::ReleaseInformation.call(
      settings: settings,
      environment: "customer-environment",
      ruby_version: "ruby from host /private",
      rails_version: "rails secret"
    )

    assert_equal "unknown", payload.dig(:release, :id)
    assert_nil payload.dig(:release, :build_time)
    assert_equal "unknown", payload.fetch(:environment)
    assert_equal({ ruby: "unknown", rails: "unknown" }, payload.fetch(:runtime))
    refute_match(/private|secret|host/, payload.to_s)
  end
end
