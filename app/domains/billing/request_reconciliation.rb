# frozen_string_literal: true

module Billing
  class RequestReconciliation
    PROVIDER_WINDOW = 1.hour
    SUBSCRIPTION_WINDOW = 15.minutes
    MAX_PER_PROVIDER_WINDOW = 100

    def initialize(auditor:, clock: -> { Time.current }, max_per_provider: MAX_PER_PROVIDER_WINDOW,
      provider_window: PROVIDER_WINDOW, subscription_window: SUBSCRIPTION_WINDOW,
      enqueue: ->(id) { ReconciliationJob.perform_later(reconciliation_run_id: id) })
      @auditor = auditor
      @clock = clock
      @max_per_provider = Integer(max_per_provider)
      @provider_window = provider_window
      @subscription_window = subscription_window
      @enqueue = enqueue
    end

    def call(organization_id:, subscription_id:, actor_user:, authorization:)
      authorize!(actor_user, authorization)
      subscription = exact_subscription(organization_id, subscription_id)
      create_and_dispatch(subscription, source: "targeted", actor_user_id: actor_user.id)
    end

    def scheduled(subscription:)
      unless subscription.is_a?(Subscription) && subscription.provider_backed?
        raise ArgumentError, "scheduled reconciliation subscription is invalid"
      end

      create_and_dispatch(subscription, source: "scheduled", actor_user_id: nil)
    end

    private

    def authorize!(actor_user, authorization)
      valid = actor_user&.active? && authorization.is_a?(SupportDecision) && authorization.allow? &&
        authorization.permission_key == "billing_support.manage" &&
        authorization.actor_user_id == actor_user.id.to_s
      raise SupportAccessDenied.new(reason_code: "billing_support_permission_missing") unless valid
    end

    def exact_subscription(organization_id, subscription_id)
      subscription = Subscription.find_by!(id: subscription_id, organization_id: organization_id)
      raise ActiveRecord::RecordNotFound unless subscription.provider_backed?

      subscription
    rescue ActiveRecord::RecordNotFound
      raise SupportAccessDenied.new(reason_code: "billing_support_subscription_unavailable"), cause: nil
    end

    def create_and_dispatch(subscription, source:, actor_user_id:)
      run = reserve(subscription, source: source, actor_user_id: actor_user_id)
      dispatch(run)
      run.summary
    end

    def reserve(subscription, source:, actor_user_id:)
      ReconciliationRun.transaction do
        lock_provider!(subscription.provider, subscription.provider_environment)
        existing = ReconciliationRun.active.find_by(subscription_id: subscription.id)
        next existing if existing

        enforce_rate!(subscription)
        now = @clock.call
        run = ReconciliationRun.create!(
          organization_id: subscription.organization_id,
          subscription_id: subscription.id,
          requested_by_user_id: actor_user_id,
          provider: subscription.provider,
          environment: subscription.provider_environment,
          source: source,
          state: "queued",
          requested_at: now,
          created_at: now,
          updated_at: now
        )
        audit_request(run)
        run
      end
    rescue ActiveRecord::RecordNotUnique
      ReconciliationRun.active.find_by!(subscription_id: subscription.id)
    end

    def lock_provider!(provider, environment)
      key = "billing-reconciliation:#{provider}:#{environment}"
      sql = ReconciliationRun.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(hashtextextended(?, 0))", key ])
      ReconciliationRun.connection.execute(sql)
    end

    def enforce_rate!(subscription)
      now = @clock.call
      provider_count = ReconciliationRun.where(
        provider: subscription.provider,
        environment: subscription.provider_environment,
        requested_at: (now - @provider_window)..
      ).count
      recent = ReconciliationRun.where(subscription_id: subscription.id)
        .where(requested_at: (now - @subscription_window)..).exists?
      return unless provider_count >= @max_per_provider || recent

      raise ReconciliationRateLimited.new(retry_after: retry_after(subscription, now))
    end

    def retry_after(subscription, now)
      oldest_provider = ReconciliationRun.where(
        provider: subscription.provider,
        environment: subscription.provider_environment,
        requested_at: (now - @provider_window)..
      ).minimum(:requested_at)
      latest_subscription = ReconciliationRun.where(subscription_id: subscription.id).maximum(:requested_at)
      candidates = []
      candidates << oldest_provider + @provider_window if oldest_provider
      candidates << latest_subscription + @subscription_window if latest_subscription
      [ ((candidates.max || now + 1.minute) - now).ceil, 1 ].max
    end

    def dispatch(run)
      return run if run.enqueued_at

      @enqueue.call(run.id)
      run.with_lock { run.update!(enqueued_at: @clock.call) unless run.enqueued_at }
      run
    rescue StandardError
      raise ReconciliationRetry
    end

    def audit_request(run)
      @auditor.record!(
        organization_id: run.organization_id,
        actor_user_id: run.requested_by_user_id,
        action: "billing.reconciliation_requested",
        target_type: "BillingReconciliation",
        target_id: run.id,
        result: "succeeded",
        metadata: { provider: run.provider, source: run.source }
      )
    end
  end
end
