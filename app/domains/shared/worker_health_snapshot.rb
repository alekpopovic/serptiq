# frozen_string_literal: true

require "time"

module Shared
  class WorkerHealthSnapshot
    KINDS = %w[Supervisor Dispatcher Scheduler Worker].freeze

    Summary = Data.define(:status, :process_count, :healthy_count, :stale_count, :kinds, :checked_at) do
      def healthy?
        status == "healthy"
      end
    end

    def self.call(scope: SolidQueue::Process.all, now: Time.current,
      alive_threshold: SolidQueue.process_alive_threshold)
      new(scope: scope, now: now, alive_threshold: alive_threshold).call
    end

    def initialize(scope:, now:, alive_threshold:)
      @scope = scope
      @now = now
      @stale_before = now - alive_threshold
    end

    def call
      rows = @scope.pluck(:kind, :last_heartbeat_at)
      stale_count = rows.count { |_kind, heartbeat| heartbeat < @stale_before }
      kinds = KINDS.to_h { |kind| [ kind.downcase.to_sym, rows.count { |row_kind, _heartbeat| row_kind == kind } ] }
      process_count = rows.length
      healthy_count = process_count - stale_count
      status = if process_count.zero?
        "inactive"
      elsif stale_count.zero?
        "healthy"
      else
        "degraded"
      end

      Summary.new(status, process_count, healthy_count, stale_count, kinds.freeze, @now.utc.iso8601).freeze
    end
  end
end
