# frozen_string_literal: true

require "test_helper"
require Rails.root.join("config/searchops/database_configuration_validator")

class PostgreSQLConfigurationTest < ActiveSupport::TestCase
  test "defines four PostgreSQL connections with bounded pools and application names" do
    settings = Rails.application.config.x.searchops
    configurations = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).index_by(&:name)

    assert_equal %w[cable cache primary queue], configurations.keys.sort
    assert configurations.values.all? { |configuration| configuration.adapter == "postgresql" }
    assert_equal settings.fetch(:primary_database_pool), configurations.fetch("primary").max_connections
    assert_equal settings.fetch(:queue_database_pool), configurations.fetch("queue").max_connections
    assert_equal settings.fetch(:cache_database_pool), configurations.fetch("cache").max_connections
    assert_equal settings.fetch(:cable_database_pool), configurations.fetch("cable").max_connections
    assert configurations.all? do |name, configuration|
      configuration.configuration_hash.fetch(:application_name).end_with?("-#{name}")
    end
  end

  test "all four configured database connections initialize against PostgreSQL" do
    results = Shared::DatabaseConnections::CONNECTIONS.keys.map do |database|
      Shared::DatabaseHealthCheck.call(database: database)
    end

    assert results.all?(&:ready?), results.map(&:to_h).inspect
    adapters = Shared::DatabaseConnections::CONNECTIONS.values.map do |connection_class|
      connection_class.connection_pool.with_connection(&:adapter_name)
    end
    assert_equal [ "PostgreSQL" ], adapters.uniq
  end

  test "primary database enables only the justified UUID and case-insensitive text extensions" do
    connection = Shared::DatabaseConnections::Primary.connection

    assert connection.extension_enabled?("pgcrypto")
    assert connection.extension_enabled?("citext")
    assert_equal [ "citext", "pg_catalog.plpgsql", "pgcrypto" ], connection.extensions.sort
  end

  test "separate queue cache and cable schemas load without application extensions" do
    expected_tables = {
      queue: "solid_queue_jobs",
      cache: "solid_cache_entries",
      cable: "solid_cable_messages"
    }

    expected_tables.each do |database, table|
      connection = Shared::DatabaseConnections.fetch(database).connection

      assert connection.data_source_exists?(table), "expected #{table} in #{database} database"
      assert_equal [ "pg_catalog.plpgsql" ], connection.extensions
    end
  end

  test "health check rejects unsafe timeout bounds and unknown connections" do
    assert_raises(ArgumentError) { Shared::DatabaseHealthCheck.call(timeout_ms: 0) }
    assert_raises(ArgumentError) { Shared::DatabaseHealthCheck.call(timeout_ms: 5001) }
    assert_raises(ArgumentError) { Shared::DatabaseHealthCheck.call(database: :unknown) }
  end

  test "health check uses only SELECT 1 with a strict transaction-local timeout" do
    statements = []
    connection = Struct.new(:statements) do
      def transaction(requires_new:)
        raise "requires a new transaction" unless requires_new
        yield
      end

      def execute(statement)
        statements << statement
      end

      def select_value(statement)
        statements << statement
        "1"
      end
    end.new(statements)
    pool = Struct.new(:connection) do
      def with_connection
        yield connection
      end
    end.new(connection)
    connection_class = Struct.new(:connection_pool).new(pool)
    times = [ 10.0, 10.004 ]

    result = Shared::DatabaseHealthCheck.call(
      timeout_ms: 250,
      clock: ->(_clock_id) { times.shift },
      connection_class: connection_class
    )

    assert result.ready?
    assert_equal 4.0, result.latency_ms
    assert_equal [ "SET LOCAL statement_timeout = 250", "SELECT 1" ], statements
  end

  test "health check maps a canceled statement to a stable timeout result" do
    connection = Struct.new(:unused) do
      def transaction(requires_new:)
        yield
      end

      def execute(_statement); end

      def select_value(_statement)
        raise ActiveRecord::QueryCanceled, "provider detail that must not escape"
      end
    end.new
    pool = Struct.new(:connection) do
      def with_connection
        yield connection
      end
    end.new(connection)
    connection_class = Struct.new(:connection_pool).new(pool)
    times = [ 10.0, 10.05 ]

    result = Shared::DatabaseHealthCheck.call(
      timeout_ms: 100,
      clock: ->(_clock_id) { times.shift },
      connection_class: connection_class
    )

    refute result.ready?
    assert_equal "timeout", result.error
    assert_equal 50.0, result.latency_ms
    assert_not_includes result.to_h.to_s, "provider detail"
  end

  test "validator rejects missing and non PostgreSQL connections without exposing URLs" do
    fake_configuration = Struct.new(:name, :adapter, :configuration_hash)
    configurations = Struct.new(:configs) do
      def configs_for(env_name:)
        configs.fetch(env_name)
      end
    end.new({
      "test" => [ fake_configuration.new("primary", "sqlite3", { application_name: "searchops-test-primary" }) ]
    })

    error = assert_raises(Searchops::Configuration::Error) do
      Searchops::DatabaseConfigurationValidator.new(environment: "test", configurations: configurations).validate!
    end

    assert_includes error.message, "missing database connections: queue, cache, cable"
    assert_includes error.message, "database primary must use PostgreSQL"
    assert_not_includes error.message, "url"
  end

  test "UUID is the default application generator key while Solid tables retain bigint IDs" do
    generator_options = Rails.application.config.generators.options.fetch(:active_record)

    assert_equal :uuid, generator_options.fetch(:primary_key_type)
    assert_match(/create_table "solid_queue_jobs"/, Rails.root.join("db/queue_schema.rb").read)
    assert_match(/t\.bigint "job_id"/, Rails.root.join("db/queue_schema.rb").read)
  end
end
