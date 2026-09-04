# frozen_string_literal: true

module Shared
  class DatabaseHealthCheck
    QUERY = "SELECT 1".freeze
    MINIMUM_TIMEOUT_MS = 50
    MAXIMUM_TIMEOUT_MS = 5000

    Result = Data.define(:database, :ready, :latency_ms, :error) do
      def ready?
        ready
      end
    end

    def self.call(database: :primary, timeout_ms: default_timeout_ms, clock: Process.method(:clock_gettime),
      connection_class: nil)
      new(database: database, timeout_ms: timeout_ms, clock: clock, connection_class: connection_class).call
    end

    def self.default_timeout_ms
      Rails.application.config.x.searchops.fetch(:database_health_timeout_ms)
    end

    def initialize(database:, timeout_ms:, clock:, connection_class:)
      @database = database.to_sym
      @connection_class = connection_class || DatabaseConnections.fetch(@database)
      @timeout_ms = Integer(timeout_ms)
      @clock = clock
      unless (MINIMUM_TIMEOUT_MS..MAXIMUM_TIMEOUT_MS).cover?(@timeout_ms)
        raise ArgumentError, "timeout_ms must be between #{MINIMUM_TIMEOUT_MS} and #{MAXIMUM_TIMEOUT_MS}"
      end
    end

    def call
      started_at = monotonic_time
      value = with_connection do |connection|
        connection.transaction(requires_new: true) do
          connection.execute("SET LOCAL statement_timeout = #{@timeout_ms}")
          connection.select_value(QUERY)
        end
      end
      ready = value.to_i == 1
      Result.new(@database, ready, elapsed_ms(started_at), ready ? nil : "unexpected_result")
    rescue ActiveRecord::QueryCanceled
      Result.new(@database, false, elapsed_ms(started_at), "timeout")
    rescue ActiveRecord::ActiveRecordError
      Result.new(@database, false, elapsed_ms(started_at), "unavailable")
    end

    private

    def with_connection(&block)
      @connection_class.connection_pool.with_connection(&block)
    end

    def monotonic_time
      @clock.call(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms(started_at)
      ((monotonic_time - started_at) * 1000).round(2)
    end
  end
end
