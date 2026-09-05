# frozen_string_literal: true

require "test_helper"
require Rails.root.join("config/searchops/configuration")

class SearchopsConfigurationTest < ActiveSupport::TestCase
  CONFIG_PATH = Rails.root.join("config/searchops.yml")

  test "loads deterministic test values and typed settings" do
    configuration = load_configuration(environment: "test")

    assert_equal URI("https://searchops.test"), configuration.fetch(:application_origin)
    assert_equal 25, configuration.fetch(:crawler_max_urls_per_scan)
    assert_equal 2, configuration.fetch(:crawler_project_concurrent_scans)
    assert_equal 10, configuration.fetch(:crawler_global_concurrent_scans)
    assert_equal 4, configuration.fetch(:crawler_global_fetch_concurrency)
    assert_equal 2, configuration.fetch(:crawler_organization_fetch_concurrency_per_scan)
    assert_equal 1, configuration.fetch(:crawler_host_fetch_concurrency)
    assert_equal 20, configuration.fetch(:crawler_global_request_rate)
    assert_equal 5, configuration.fetch(:crawler_organization_request_rate_per_scan)
    assert_equal 2, configuration.fetch(:crawler_host_request_rate)
    assert_equal 60.0, configuration.fetch(:crawler_fetch_permit_duration)
    assert_equal 1800.0, configuration.fetch(:crawler_scan_max_duration)
    assert_equal 1.0, configuration.fetch(:crawler_host_backoff_base)
    assert_equal 60.0, configuration.fetch(:crawler_host_backoff_max)
    assert_equal 1.0, configuration.fetch(:crawler_throttle_poll_interval)
    assert_equal 10, configuration.fetch(:crawler_frontier_lease_batch_size)
    assert_equal 120, configuration.fetch(:crawler_frontier_lease_duration)
    assert_equal 3, configuration.fetch(:crawler_frontier_max_attempts)
    assert_equal 1, configuration.fetch(:crawler_frontier_retry_base_delay)
    assert_equal 3.0, configuration.fetch(:crawler_robots_dns_timeout)
    assert_equal 2.0, configuration.fetch(:crawler_robots_open_timeout)
    assert_equal 5.0, configuration.fetch(:crawler_robots_read_timeout)
    assert_equal 512_000, configuration.fetch(:crawler_robots_max_response_bytes)
    assert_equal 5, configuration.fetch(:crawler_robots_max_redirects)
    assert configuration.fetch(:crawler_sitemap_well_known_enabled)
    assert_equal 3.0, configuration.fetch(:crawler_sitemap_dns_timeout)
    assert_equal 2.0, configuration.fetch(:crawler_sitemap_open_timeout)
    assert_equal 10.0, configuration.fetch(:crawler_sitemap_read_timeout)
    assert_equal 10_485_760, configuration.fetch(:crawler_sitemap_max_response_bytes)
    assert_equal 52_428_800, configuration.fetch(:crawler_sitemap_max_decompressed_bytes)
    assert_equal 1000, configuration.fetch(:crawler_sitemap_max_documents)
    assert_equal 50_000, configuration.fetch(:crawler_sitemap_max_entries_per_document)
    assert_equal 200_000, configuration.fetch(:crawler_sitemap_max_entries_per_scan)
    assert_equal 3, configuration.fetch(:crawler_sitemap_max_index_depth)
    assert_equal 32, configuration.fetch(:crawler_sitemap_max_xml_depth)
    assert_equal 5, configuration.fetch(:crawler_sitemap_max_redirects)
    assert_equal 5.0, configuration.fetch(:crawler_connect_timeout)
    assert_equal 3.0, configuration.fetch(:crawler_dns_timeout)
    assert_equal 5.0, configuration.fetch(:crawler_tls_timeout)
    assert_equal 10.0, configuration.fetch(:crawler_header_timeout)
    assert_equal 45.0, configuration.fetch(:crawler_total_timeout)
    assert_equal 65_536, configuration.fetch(:crawler_max_header_bytes)
    assert_equal 26_214_400, configuration.fetch(:crawler_max_decompressed_bytes)
    assert_equal 100, configuration.fetch(:crawler_max_decompression_ratio)
    assert_equal 2, configuration.fetch(:crawler_safe_retries)
    assert_equal 0.25, configuration.fetch(:crawler_retry_base_delay)
    assert_equal 5.0, configuration.fetch(:crawler_retry_max_delay)
    assert_equal false, configuration.fetch(:crawler_egress_enforced)
    assert_equal 45.0, configuration.fetch(:browser_timeout)
    assert_equal 360.0, configuration.fetch(:browser_lease_duration)
    assert_equal 200, configuration.fetch(:browser_max_requests)
    assert_equal 52_428_800, configuration.fetch(:browser_max_response_bytes)
    assert configuration.fetch(:browser_screenshot_enabled)
    assert_equal false, configuration.fetch(:oauth_google_enabled)
    assert_equal 2.0, configuration.fetch(:oauth_http_open_timeout)
    assert_equal 5.0, configuration.fetch(:oauth_http_read_timeout)
    assert_equal 262_144, configuration.fetch(:oauth_http_max_response_bytes)
    assert_equal 2, configuration.fetch(:oauth_http_safe_retries)
    assert_equal 300.0, configuration.fetch(:oauth_jwks_cache_ttl)
    assert_equal 16, configuration.fetch(:oauth_jwks_max_keys)
    assert_equal 60.0, configuration.fetch(:oauth_oidc_clock_skew)
    assert_equal 7200.0, configuration.fetch(:oauth_oidc_max_token_lifetime)
    assert_equal 600.0, configuration.fetch(:oauth_transaction_ttl)
    assert_equal 86_400.0, configuration.fetch(:oauth_transaction_retention)
    assert_equal 300.0, configuration.fetch(:oauth_start_rate_window)
    assert_equal 20, configuration.fetch(:oauth_start_max_per_ip)
    assert_equal 10, configuration.fetch(:oauth_start_max_per_session)
    assert_equal 5, configuration.fetch(:oauth_start_max_open_per_ip)
    assert_equal 2, configuration.fetch(:oauth_start_max_open_per_session)
    assert_equal 2.0, configuration.fetch(:billing_http_open_timeout)
    assert_equal 5.0, configuration.fetch(:billing_http_read_timeout)
    assert_equal 5.0, configuration.fetch(:billing_http_write_timeout)
    assert_equal 524_288, configuration.fetch(:billing_http_max_response_bytes)
    assert_equal false, configuration.fetch(:dns_verification_enabled)
    assert_equal 3.0, configuration.fetch(:dns_verification_timeout)
    assert_equal 32, configuration.fetch(:dns_verification_max_records)
    assert_equal 4096, configuration.fetch(:dns_verification_max_response_bytes)
    assert_equal 5, configuration.fetch(:dns_verification_max_cname_hops)
    assert_equal 8, configuration.fetch(:dns_verification_max_delegations)
    assert_equal false, configuration.fetch(:http_verification_enabled)
    assert_equal 3.0, configuration.fetch(:verification_http_dns_timeout)
    assert_equal 2.0, configuration.fetch(:verification_http_open_timeout)
    assert_equal 5.0, configuration.fetch(:verification_http_read_timeout)
    assert_equal 262_144, configuration.fetch(:verification_http_max_response_bytes)
    assert_equal 2, configuration.fetch(:verification_http_max_redirects)
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
      "SEARCHOPS_CRAWLER_ROBOTS_MAX_RESPONSE_BYTES" => "511999",
      "SEARCHOPS_CRAWLER_ROBOTS_MAX_REDIRECTS" => "6",
      "SEARCHOPS_CRAWLER_SITEMAP_MAX_RESPONSE_BYTES" => "52428801",
      "SEARCHOPS_CRAWLER_SITEMAP_MAX_DECOMPRESSED_BYTES" => "1000",
      "SEARCHOPS_CRAWLER_SITEMAP_MAX_DOCUMENTS" => "10001",
      "SEARCHOPS_CRAWLER_SITEMAP_MAX_ENTRIES_PER_DOCUMENT" => "50001",
      "SEARCHOPS_CRAWLER_SITEMAP_MAX_ENTRIES_PER_SCAN" => "1000001",
      "SEARCHOPS_CRAWLER_SITEMAP_MAX_INDEX_DEPTH" => "11",
      "SEARCHOPS_CRAWLER_SITEMAP_MAX_XML_DEPTH" => "3",
      "SEARCHOPS_CRAWLER_SITEMAP_MAX_REDIRECTS" => "6",
      "SEARCHOPS_OAUTH_HTTP_OPEN_TIMEOUT" => "0ms",
      "SEARCHOPS_OAUTH_HTTP_MAX_RESPONSE_BYTES" => "100",
      "SEARCHOPS_OAUTH_HTTP_SAFE_RETRIES" => "4",
      "SEARCHOPS_OAUTH_TRANSACTION_TTL" => "16m",
      "SEARCHOPS_OAUTH_START_MAX_OPEN_PER_IP" => "0",
      "SEARCHOPS_BILLING_HTTP_WRITE_TIMEOUT" => "31s",
      "SEARCHOPS_BILLING_HTTP_MAX_RESPONSE_BYTES" => "100",
      "SEARCHOPS_SLACK_ENABLED" => "sometimes",
      "SEARCHOPS_BROWSER_TIMEOUT" => "45",
      "SEARCHOPS_DNS_VERIFICATION_TIMEOUT" => "11s",
      "SEARCHOPS_VERIFICATION_HTTP_MAX_REDIRECTS" => "6",
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

  test "rejects a partial object storage credential pair without exposing it" do
    environment = complete_production_environment.merge(
      "SEARCHOPS_OBJECT_STORAGE_ACCESS_KEY_ID" => "synthetic-access-id"
    )
    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(environment: "production", env: environment)
    end

    assert_includes error.message, "must be configured together"
    assert_not_includes error.message, "synthetic-access-id"
  end

  test "allows the fake billing adapter only outside protected environments" do
    development = load_configuration(
      environment: "development",
      env: { "SEARCHOPS_BILLING_PROVIDER" => "fake" }
    )
    assert_equal "fake", development.fetch(:billing_provider)

    environment = complete_production_environment.merge("SEARCHOPS_BILLING_PROVIDER" => "fake")
    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(environment: "production", env: environment)
    end
    assert_includes error.message, "limited to development and test"
  end

  test "requires protected crawl and render workers to attest infrastructure egress enforcement" do
    %w[worker_crawl worker_render].each do |role|
      environment = complete_production_environment.merge("SEARCHOPS_PROCESS_ROLE" => role)
      error = assert_raises(Searchops::Configuration::Error) do
        load_configuration(environment: "production", env: environment)
      end
      assert_includes error.message, "SEARCHOPS_CRAWLER_EGRESS_ENFORCED"

      configuration = load_configuration(
        environment: "production",
        env: environment.merge("SEARCHOPS_CRAWLER_EGRESS_ENFORCED" => "true")
      )
      assert configuration.fetch(:crawler_egress_enforced)
    end
  end

  test "rejects unsafe crawl pressure timing relationships" do
    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(
        environment: "test",
        env: { "SEARCHOPS_CRAWLER_FETCH_PERMIT_DURATION" => "45s" }
      )
    end
    assert_includes error.message, "SEARCHOPS_CRAWLER_FETCH_PERMIT_DURATION"
    assert_includes error.message, "SEARCHOPS_CRAWLER_TOTAL_TIMEOUT"

    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(
        environment: "test",
        env: {
          "SEARCHOPS_CRAWLER_HOST_BACKOFF_BASE" => "10s",
          "SEARCHOPS_CRAWLER_HOST_BACKOFF_MAX" => "5s"
        }
      )
    end
    assert_includes error.message, "SEARCHOPS_CRAWLER_HOST_BACKOFF_MAX"
    assert_includes error.message, "SEARCHOPS_CRAWLER_HOST_BACKOFF_BASE"

    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(
        environment: "test",
        env: {
          "SEARCHOPS_BROWSER_TIMEOUT" => "120s",
          "SEARCHOPS_BROWSER_LEASE_DURATION" => "120s"
        }
      )
    end
    assert_includes error.message, "SEARCHOPS_BROWSER_LEASE_DURATION"
    assert_includes error.message, "SEARCHOPS_BROWSER_TIMEOUT"
  end

  test "requires a numeric store and secrets for the Lemon Squeezy adapter" do
    environment = complete_production_environment.merge(
      "SEARCHOPS_BILLING_PROVIDER" => "lemon_squeezy",
      "SEARCHOPS_BILLING_STORE_ID" => "not-a-store",
      "SEARCHOPS_BILLING_API_KEY" => "private-api-key",
      "SEARCHOPS_BILLING_WEBHOOK_SECRET" => "private-webhook-secret"
    )
    error = assert_raises(Searchops::Configuration::Error) do
      load_configuration(environment: "production", env: environment)
    end
    assert_includes error.message, "SEARCHOPS_BILLING_STORE_ID"
    assert_not_includes error.message, "not-a-store"
    assert_not_includes error.message, "private-api-key"

    environment["SEARCHOPS_BILLING_STORE_ID"] = "1001"
    configuration = load_configuration(environment: "production", env: environment)
    assert_equal "lemon_squeezy", configuration.fetch(:billing_provider)
    assert_equal "[FILTERED]", configuration.to_h.fetch(:billing_api_key)
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
