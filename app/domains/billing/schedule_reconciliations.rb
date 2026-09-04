# frozen_string_literal: true

module Billing
  class ScheduleReconciliations
    RECENT_ENDED_WINDOW = 30.days
    SWEEP_LIMIT = 100
    STALE_RUNNING_AFTER = 15.minutes

    def initialize(requester:, clock: -> { Time.current }, limit: SWEEP_LIMIT)
      @requester = requester
      @clock = clock
      @limit = Integer(limit)
    end

    def call
      recover_stale_runs
      candidates.filter_map do |subscription|
        @requester.scheduled(subscription: subscription)
      rescue ReconciliationRateLimited
        nil
      end.freeze
    end

    private

    def candidates
      Subscription.where.not(provider: nil)
        .where("ended_at IS NULL OR ended_at >= ?", @clock.call - RECENT_ENDED_WINDOW)
        .order(:provider, :provider_environment, :id)
        .limit(@limit)
    end

    def recover_stale_runs
      now = @clock.call
      ReconciliationRun.where(state: "running").where(updated_at: ...now - STALE_RUNNING_AFTER)
        .find_each do |run|
          run.with_lock do
            next unless run.state == "running" && run.updated_at < now - STALE_RUNNING_AFTER

            run.update!(
              state: "retryable",
              failure_category: "worker_interrupted",
              next_attempt_at: now,
              enqueued_at: nil,
              updated_at: now
            )
          end
        end
    end
  end
end
