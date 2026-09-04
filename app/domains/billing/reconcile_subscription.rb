# frozen_string_literal: true

require "digest"

module Billing
  class ReconcileSubscription
    MAX_ATTEMPTS = 5
    RETRY_DELAYS = [ 5.minutes, 30.minutes, 2.hours, 6.hours ].freeze
    COMPARISON_FIELDS = {
      plan_version_id: ->(subscription, _snapshot, mapping) { [ subscription.plan_version_id, mapping.plan_version_id ] },
      status: ->(subscription, snapshot, _) { [ subscription.status, snapshot.status ] },
      access_state: ->(subscription, snapshot, _) { [ subscription.access_state, snapshot.access_state ] },
      billing_interval: ->(subscription, snapshot, _) { [ subscription.billing_interval, snapshot.billing_interval ] },
      started_at: ->(subscription, snapshot, _) { [ subscription.started_at, snapshot.started_at ] },
      current_period_starts_at: ->(subscription, snapshot, _) {
        [ subscription.current_period_starts_at, snapshot.current_period_starts_at ]
      },
      current_period_ends_at: ->(subscription, snapshot, _) {
        [ subscription.current_period_ends_at, snapshot.current_period_ends_at ]
      },
      trial_ends_at: ->(subscription, snapshot, _) { [ subscription.trial_ends_at, snapshot.trial_ends_at ] },
      cancel_at_period_end: ->(subscription, snapshot, _) {
        [ subscription.cancel_at_period_end, snapshot.cancel_at_period_end ]
      },
      canceled_at: ->(subscription, snapshot, _) { [ subscription.canceled_at, snapshot.canceled_at ] },
      access_expires_at: ->(subscription, snapshot, _) {
        [ subscription.access_expires_at, snapshot.access_expires_at ]
      },
      ended_at: ->(subscription, snapshot, _) { [ subscription.ended_at, snapshot.ended_at ] },
      provider_updated_at: ->(subscription, snapshot, _) {
        [ subscription.provider_updated_at, snapshot.provider_updated_at ]
      }
    }.freeze

    def initialize(provider_lookup:, auditor:, clock: -> { Time.current },
      projector: nil, enqueue_retry: ->(id, at) {
        ReconciliationJob.set(wait_until: at).perform_later(reconciliation_run_id: id)
      }, outbox_enqueue: ->(id) { Shared::Public.enqueue_outbox_event!(outbox_event_id: id) })
      @provider_lookup = provider_lookup
      @auditor = auditor
      @clock = clock
      @projector = projector || ProjectProviderEvent.new(auditor: auditor, clock: clock)
      @enqueue_retry = enqueue_retry
      @outbox_enqueue = outbox_enqueue
    end

    def call(reconciliation_run_id:)
      run, subscription = begin_attempt(reconciliation_run_id)
      return run.summary unless subscription

      snapshot = @provider_lookup.call(run.provider).fetch_subscription(
        reference: subscription.provider_subscription_id
      )
      validate_identity!(run, subscription, snapshot)
      mapping = exact_mapping(run, snapshot)
      return complete_ambiguous(run, snapshot, [ "plan_mapping" ]) unless mapping

      differences = differences(subscription, snapshot, mapping)
      return complete_match(run, subscription, snapshot) if differences.empty?
      return complete_ambiguous(run, snapshot, differences) unless safe_repair?(subscription, snapshot)

      repair(run, snapshot, differences)
    rescue ProviderFailure => error
      provider_failure(reconciliation_run_id, error)
    rescue WebhookProjectionFailure, SubscriptionTransitionInvalid => error
      complete_failure(reconciliation_run_id, "projection_#{safe_category(error)}")
    rescue ActiveRecord::RecordNotFound
      complete_failure(reconciliation_run_id, "local_mapping_missing")
    end

    private

    def begin_attempt(run_id)
      ReconciliationRun.transaction do
        run = ReconciliationRun.lock.find(run_id)
        return [ run, nil ] if run.terminal? || run.state == "running"

        now = @clock.call
        run.update!(
          state: "running",
          attempt_count: run.attempt_count + 1,
          started_at: run.started_at || now,
          next_attempt_at: nil,
          failure_category: nil,
          updated_at: now
        )
        subscription = Subscription.find_by!(id: run.subscription_id, organization_id: run.organization_id)
        [ run, subscription ]
      end
    end

    def validate_identity!(run, subscription, snapshot)
      customer = subscription.customer_mapping
      valid = snapshot.is_a?(SubscriptionSnapshot) && snapshot.provider == run.provider &&
        subscription.provider_environment == run.environment &&
        snapshot.subscription_reference == subscription.provider_subscription_id &&
        customer && snapshot.customer_reference == customer.provider_customer_id
      return if valid

      raise ProviderFailure.new(
        provider: run.provider,
        operation: "fetch_subscription",
        category: "malformed_response",
        retryable: false
      )
    end

    def exact_mapping(run, snapshot)
      mapping = PlanProviderMapping.find_by(
        provider: run.provider,
        environment: run.environment,
        provider_variant_id: snapshot.variant_reference,
        currency: snapshot.currency,
        billing_interval: snapshot.billing_interval,
        active: true
      )
      mapping
    end

    def differences(subscription, snapshot, mapping)
      COMPARISON_FIELDS.filter_map do |name, extractor|
        local, provider = extractor.call(subscription, snapshot, mapping)
        name.to_s unless equivalent?(local, provider)
      end
    end

    def equivalent?(local, provider)
      if time_value?(local) || time_value?(provider)
        local&.to_time == provider&.to_time
      else
        local == provider
      end
    end

    def time_value?(value)
      value.is_a?(Time) || value.is_a?(DateTime) || value.is_a?(ActiveSupport::TimeWithZone)
    end

    def safe_repair?(subscription, snapshot)
      snapshot.provider_updated_at > subscription.provider_updated_at &&
        SubscriptionLifecycle.transition_allowed?(from: subscription.status, to: snapshot.status)
    end

    def complete_match(run, subscription, snapshot)
      now = @clock.call
      ReconciliationRun.transaction do
        locked = ReconciliationRun.lock.find(run.id)
        subscription.with_lock do
          subscription.update_columns(last_synced_at: [ now, snapshot.provider_updated_at ].max)
        end
        finish!(locked, "matched", snapshot, [], now)
        audit_result(locked, "matched")
        locked.summary
      end
    end

    def complete_ambiguous(run, snapshot, differences)
      complete_terminal(run.id, "ambiguous", snapshot, differences, nil)
    end

    def repair(run, snapshot, differences)
      outcome = nil
      summary = ReconciliationRun.transaction do
        locked = ReconciliationRun.lock.find(run.id)
        event = ProviderEvent.new(
          provider: snapshot.provider,
          reference: locked.provider_event_id,
          name: "subscription.updated",
          occurred_at: snapshot.provider_updated_at,
          customer_reference: snapshot.customer_reference,
          subscription_reference: snapshot.subscription_reference,
          variant_reference: snapshot.variant_reference,
          subscription_snapshot: snapshot
        )
        outcome = @projector.call(webhook_event: locked, provider_event: event)
        unless outcome.result == "applied"
          raise WebhookProjectionFailure.new(category: "reconciliation_not_applied", retryable: false)
        end
        now = @clock.call
        finish!(locked, "repaired", snapshot, differences, now)
        audit_result(locked, "repaired")
        locked.summary
      end
      enqueue_outbox(outcome)
      summary
    end

    def complete_terminal(run_id, state, snapshot, differences, failure)
      ReconciliationRun.transaction do
        run = ReconciliationRun.lock.find(run_id)
        return run.summary if run.terminal?

        now = @clock.call
        finish!(run, state, snapshot, differences, now, failure: failure)
        audit_result(run, state)
        run.summary
      end
    end

    def finish!(run, state, snapshot, differences, now, failure: nil)
      run.update!(
        state: state,
        provider_snapshot: safe_snapshot(snapshot, run),
        difference_fields: differences,
        failure_category: failure,
        provider_updated_at: snapshot&.provider_updated_at,
        completed_at: now,
        next_attempt_at: nil,
        updated_at: now
      )
    end

    def provider_failure(run_id, error)
      return complete_failure(run_id, "provider_not_found", state: "missing") if error.category == "not_found"
      return complete_failure(run_id, "provider_#{error.category}") unless error.retryable?

      retry_provider(run_id, error)
    end

    def retry_provider(run_id, error)
      run = ReconciliationRun.transaction do
        record = ReconciliationRun.lock.find(run_id)
        return record.summary if record.terminal?
        return complete_failure(run_id, "provider_#{error.category}") if record.attempt_count >= MAX_ATTEMPTS

        now = @clock.call
        wait = error.retry_after || RETRY_DELAYS.fetch([ record.attempt_count - 1, RETRY_DELAYS.length - 1 ].min)
        record.update!(
          state: "retryable",
          failure_category: "provider_#{error.category}",
          next_attempt_at: now + wait,
          updated_at: now
        )
        audit_result(record, "retryable")
        record
      end
      @enqueue_retry.call(run.id, run.next_attempt_at)
      run.summary
    rescue StandardError => enqueue_error
      raise enqueue_error if enqueue_error.is_a?(ReconciliationRateLimited)

      raise ReconciliationRetry
    end

    def complete_failure(run_id, category, state: "failed")
      run = ReconciliationRun.find(run_id)
      complete_terminal(run.id, state, nil, [], category)
    end

    def safe_snapshot(snapshot, run)
      return {} unless snapshot

      {
        "status" => snapshot.status,
        "access_state" => snapshot.access_state,
        "billing_interval" => snapshot.billing_interval,
        "currency" => snapshot.currency,
        "plan_version_id" => PlanProviderMapping.find_by(
          provider: run.provider, environment: run.environment,
          provider_variant_id: snapshot.variant_reference, active: true
        )&.plan_version_id,
        "started_at" => timestamp(snapshot.started_at),
        "current_period_starts_at" => timestamp(snapshot.current_period_starts_at),
        "current_period_ends_at" => timestamp(snapshot.current_period_ends_at),
        "trial_ends_at" => timestamp(snapshot.trial_ends_at),
        "cancel_at_period_end" => snapshot.cancel_at_period_end,
        "canceled_at" => timestamp(snapshot.canceled_at),
        "access_expires_at" => timestamp(snapshot.access_expires_at),
        "ended_at" => timestamp(snapshot.ended_at),
        "provider_updated_at" => timestamp(snapshot.provider_updated_at),
        "subscription_reference_digest" => Digest::SHA256.hexdigest(snapshot.subscription_reference)
      }.compact
    end

    def timestamp(value)
      value&.iso8601(6)
    end

    def audit_result(run, state)
      @auditor.record!(
        organization_id: run.organization_id,
        actor_user_id: run.requested_by_user_id,
        action: "billing.reconciliation_#{state}",
        target_type: "BillingReconciliation",
        target_id: run.id,
        result: state.in?(%w[matched repaired]) ? "succeeded" : "failed",
        metadata: {
          provider: run.provider,
          source: run.source,
          state: state,
          difference_count: run.difference_fields.length,
          failure_category: run.failure_category
        }.compact
      )
    end

    def safe_category(error)
      value = error.respond_to?(:category) ? error.category : error.class.name.demodulize.underscore
      ValueNormalization::KEY_PATTERN.match?(value.to_s) ? value : "invalid_projection"
    end

    def enqueue_outbox(outcome)
      outcome.outbox_event_ids.each { |id| @outbox_enqueue.call(id) }
    rescue StandardError => error
      Rails.error.report(
        error,
        handled: true,
        severity: :error,
        context: { "operation" => "billing_reconciliation_outbox_enqueue" }
      )
    end
  end
end
