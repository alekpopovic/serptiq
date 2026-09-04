# frozen_string_literal: true

require "test_helper"
require Rails.root.join("config/searchops/configuration")

class SearchopsConfigurationTest < ActiveSupport::TestCase
  CONFIG_PATH = Rails.root.join("config/searchops.yml")

  test "loads deterministic test values and typed settings" do
    configuration = load_configuration(environment: "test")

    assert_equal URI("https://searchops.test"), configuration.fetch(:application_origin)
    assert_equal 25, configuration.fetch(:crawler_max_urls_per_scan)
    assert_equal 5.0, configuration.fetch(:crawler_connect_timeout)
    assert_equal false, configuration.fetch(:oauth_google_enabled)
    assert_equal 2.0, configuration.fetch(:oauth_http_open_timeout)
    assert_equal 5.0, configuration.fetch(:oauth_http_read_timeout)
    assert_equal 262_144, configuration.fetch(:oauth_http_max_response_bytes)
    assert_equal 2, configuration.fetch(:oauth_http_safe_retries)
  end

  test "environment overrides public config and credentials for secrets" do
    configuration = load_configuration(
      environment: "development",
      env: {
        "SEARCHOPS_CRAWLER_CONNECT_TIMEOUT" => "250ms",
        "SEARCHOPS_OAUTH_GOOGLE_ENABLED" => "yes",
        "SEARCHOPS_OAUTH_GOOGLE_CLIENT_ID" => "public-client-id",
        "SEARCHOPS_OAUTH_GOOGLE_CLIENT_SECRET" => "runtime-secret"
      },
      credentials: { oauth: { google: { client_secret: "credential-secret" } } }
    )

    assert_equal 0.25, configuration.fetch(:crawler_connect_timeout)
    assert configuration.fetch(:oauth_google_enabled)
    assert_equal "runtime-secret", configuration.secret(:oauth_google_client_secret)
    assert_equal "[FILTERED]", configuration.to_h.fetch(:oauth_google_client_secret)
    assert_not_includes configuration.inspect, "runtime-secret"
  end

  test "rejects invalid integer bounds boolean duration enum and origin" do
    invalid_values = {
      "SEARCHOPS_CRAWLER_MAX_REDIRECTS" => "21",
      "SEARCHOPS_OAUTH_HTTP_OPEN_TIMEOUT" => "0ms",
      "SEARCHOPS_OAUTH_HTTP_MAX_RESPONSE_BYTES" => "100",
      "SEARCHOPS_OAUTH_HTTP_SAFE_RETRIES" => "4",
      "SEARCHOPS_SLACK_ENABLED" => "sometimes",
      "SEARCHOPS_BROWSER_TIMEOUT" => "45",
      "SEARCHOPS_PROCESS_ROLE" => "root",
      "SEARCHOPS_APPLICATION_ORIGIN" => "https://user:password@example.com/path?token=secret"
    }

    invalid_values.each do |key, value|
      error = assert_raises(Searchops::Configuration::Error) do
        load_configuration(environment: "test", env: { key => value })
      end
      assert_includes error.message, key
      assert_not_includes error.message, value
    end
  end

  test "requires protected settings without exposing supplied secrets" do
    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(
        environment: "production",
        env: {
          "SEARCHOPS_APPLICATION_ORIGIN" => "https://app.acme.com",
          "SECRET_KEY_BASE" => "do-not-print-this-secret"
        }
      )
    end

    assert_includes error.message, "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEYS"
    assert_includes error.message, "DATABASE_URL or SEARCHOPS_DATABASE_PASSWORD"
    assert_not_includes error.message, "do-not-print-this-secret"
  end

  test "rejects an unsafe protected origin" do
    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(environment: "production", env: { "SEARCHOPS_APPLICATION_ORIGIN" => "http://127.0.0.1:3000" })
    end

    assert_includes error.message, "public HTTPS origin"
  end

  test "accepts complete production configuration" do
    configuration = load_configuration(environment: "production", env: complete_production_environment)

    assert_equal "s3", configuration.fetch(:object_storage_service)
    assert_equal "release-sha", configuration.fetch(:release_sha)
    assert_equal 2, configuration.secret(:encryption_primary_keys).size
  end

  test "rejects aggregate database pools above the declared capacity" do
    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(
        environment: "test",
        env: {
          "SEARCHOPS_PRIMARY_DATABASE_POOL" => "10",
          "SEARCHOPS_QUEUE_DATABASE_POOL" => "10",
          "SEARCHOPS_CACHE_DATABASE_POOL" => "10",
          "SEARCHOPS_CABLE_DATABASE_POOL" => "10",
          "SEARCHOPS_DATABASE_PROCESS_COUNT" => "3",
          "SEARCHOPS_DATABASE_RESERVED_CONNECTIONS" => "5",
          "SEARCHOPS_DATABASE_CONNECTION_BUDGET" => "100"
        }
      )
    end

    assert_includes error.message, "database connection demand 125 exceeds"
  end

  test "rejects non-PostgreSQL database URLs without echoing credentials" do
    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(environment: "test", env: { "DATABASE_URL" => "mysql://user:do-not-print@database.invalid/app" })
    end

    assert_includes error.message, "DATABASE_URL"
    assert_not_includes error.message, "do-not-print"
  end

  test "rejects a partial protected database URL set" do
    environment = complete_production_environment.dup
    environment.delete("QUEUE_DATABASE_URL")

    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(environment: "production", env: environment)
    end

    assert_includes error.message, "QUEUE_DATABASE_URL is required"
    assert_not_includes error.message, "database.invalid"
  end

  test "example environment leaves every declared secret blank" do
    example = Rails.root.join(".env.example").each_line(chomp: true).filter_map do |line|
      next if line.empty? || line.start_with?("#")

      line.split("=", 2)
    end.to_h
    secret_environment_keys = Searchops::Configuration::DEFINITIONS.values.filter_map do |definition|
      definition.env_key if definition.secret
    end

    (secret_environment_keys + [ "RAILS_MASTER_KEY" ]).each do |key|
      assert example.key?(key), "expected .env.example to inventory #{key}"
      assert_empty example.fetch(key)
    end
  end

  private

  def load_configuration(environment:, env: {}, credentials: {})
    Searchops::Configuration.load(
      environment: environment,
      env: env,
      credentials: credentials,
      path: CONFIG_PATH
    )
  end

  def complete_production_environment
    {
      "SEARCHOPS_APPLICATION_ORIGIN" => "https://app.acme.com",
      "SEARCHOPS_RELEASE_SHA" => "release-sha",
      "SEARCHOPS_OBJECT_STORAGE_BUCKET" => "private-bucket",
      "SEARCHOPS_OBJECT_STORAGE_REGION" => "eu-central-1",
      "SECRET_KEY_BASE" => "secret-key-base",
      "DATABASE_URL" => "postgresql://database.invalid/searchops",
      "QUEUE_DATABASE_URL" => "postgresql://database.invalid/searchops_queue",
      "CACHE_DATABASE_URL" => "postgresql://database.invalid/searchops_cache",
      "CABLE_DATABASE_URL" => "postgresql://database.invalid/searchops_cable",
      "SEARCHOPS_DATABASE_CONNECTION_BUDGET" => "25",
      "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEYS" => "current-key,previous-key",
      "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => "deterministic-key",
      "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" => "derivation-salt"
    }
  end
end
