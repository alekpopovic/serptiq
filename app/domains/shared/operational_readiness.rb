# frozen_string_literal: true

module Shared
  class OperationalReadiness
    ROLE_DATABASES = {
      web: %i[primary queue].freeze,
      scheduler: %i[queue].freeze,
      worker_default: %i[primary queue].freeze,
      worker_crawl: %i[primary queue].freeze,
      worker_render: %i[primary queue].freeze,
      worker_analysis: %i[primary queue].freeze,
      worker_report: %i[primary queue].freeze
    }.freeze

    Check = Data.define(:database, :ready, :latency_ms, :reason) do
      def ready?
        ready
      end
    end

    Result = Data.define(:role, :checks) do
      def ready?
        checks.all?(&:ready?)
      end

      def public_payload
        {
          status: ready? ? "ready" : "not_ready",
          checks: { postgresql: ready? ? "ok" : "unavailable" }
        }.freeze
      end
    end

    def self.call(role:, checker: DatabaseHealthCheck, timeout_ms: nil)
      new(role: role, checker: checker, timeout_ms: timeout_ms).call
    end

    def initialize(role:, checker:, timeout_ms:)
      @role = role.to_sym
      @databases = ROLE_DATABASES.fetch(@role) do
        raise ArgumentError, "unknown readiness process role #{role.inspect}"
      end
      @checker = checker
      @timeout_ms = timeout_ms || DatabaseHealthCheck.default_timeout_ms
    end

    def call
      checks = @databases.map { |database| check(database) }.freeze
      Result.new(@role, checks)
    end

    private

    def check(database)
      result = @checker.call(database: database, timeout_ms: @timeout_ms)
      Check.new(database, result.ready?, result.latency_ms, result.error)
    rescue StandardError
      Check.new(database, false, nil, "unavailable")
    end
  end
end
