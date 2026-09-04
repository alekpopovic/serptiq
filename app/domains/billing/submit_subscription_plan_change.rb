# frozen_string_literal: true

module Billing
  class SubmitSubscriptionPlanChange
    def initialize(provider_lookup:, auditor:, clock: -> { Time.current }, outbox: Shared::Public,
      outbox_enqueue: ->(id) { Shared::Public.enqueue_outbox_event!(outbox_event_id: id) })
      @provider_lookup = provider_lookup
      @auditor = auditor
      @clock = clock
      @outbox = outbox
      @outbox_enqueue = outbox_enqueue
    end

    def call(organization_id:, subscription_change_id:)
      change, subscription, provider, target_mapping = load_context(
        organization_id, subscription_change_id
      )
      return change.summary unless subscription

      snapshot = subscription_snapshot(subscription)
      returned = provider.change_subscription(
        subscription: snapshot,
        variant_reference: target_mapping.provider_variant_id,
        idempotency_key: "plan-change:#{change.id}:#{change.idempotency_digest.first(24)}"
      )
      validate_returned!(returned, subscription, target_mapping)
      mark_submitted(change, subscription)
    rescue ProviderFailure => error
      raise PlanChangeRetry if error.retryable?

      mark_failed(organization_id, subscription_change_id, error.category)
    end

    private

    def load_context(organization_id, change_id)
      SubscriptionChange.transaction do
        change = SubscriptionChange.lock.find_by!(id: change_id, organization_id: organization_id)
        return [ change, nil, nil, nil ] unless SubscriptionChange::ACTIVE_STATES.include?(change.state)
        raise PlanChangeRetry if @clock.call < change.effective_at

        subscription = Subscription.lock.find_by!(id: change.subscription_id, organization_id: organization_id)
        unless subscription.plan_version_id == change.from_plan_version_id && subscription.current?
          change.update!(state: "canceled", updated_at: @clock.call)
          return [ change, nil, nil, nil ]
        end
        provider = @provider_lookup.call(subscription.provider)
        target_mapping = PlanProviderMapping.find_by!(
          plan_version_id: change.target_plan_version_id,
          provider: subscription.provider,
          environment: subscription.provider_environment,
          currency: subscription.currency_snapshot,
          billing_interval: change.target_billing_interval,
          active: true
        )
        [ change, subscription, provider, target_mapping ]
      end
    rescue ActiveRecord::RecordNotFound
      raise PlanChangeConflict.new(reason_code: "billing_plan_change_context_missing"), cause: nil
    end

    def subscription_snapshot(subscription)
      mapping = PlanProviderMapping.find_by!(
        plan_version_id: subscription.plan_version_id,
        provider: subscription.provider,
        environment: subscription.provider_environment,
        currency: subscription.currency_snapshot,
        billing_interval: subscription.billing_interval,
        active: true
      )
      SubscriptionSnapshot.new(
        provider: subscription.provider,
        customer_reference: subscription.customer_mapping.provider_customer_id,
        subscription_reference: subscription.provider_subscription_id,
        variant_reference: mapping.provider_variant_id,
        status: subscription.status,
        access_state: subscription.access_state,
        billing_interval: subscription.billing_interval,
        currency: subscription.currency_snapshot,
        current_period_starts_at: subscription.current_period_starts_at,
        current_period_ends_at: subscription.current_period_ends_at,
        trial_ends_at: subscription.trial_ends_at,
        started_at: subscription.started_at,
        cancel_at_period_end: subscription.cancel_at_period_end,
        canceled_at: subscription.canceled_at,
        access_expires_at: subscription.access_expires_at,
        ended_at: subscription.ended_at,
        provider_updated_at: subscription.provider_updated_at,
        metadata: subscription.provider_metadata
      )
    rescue ActiveRecord::RecordNotFound
      raise PlanChangeConflict.new(reason_code: "billing_plan_change_mapping_missing"), cause: nil
    end

    def validate_returned!(returned, subscription, mapping)
      valid = returned.is_a?(SubscriptionSnapshot) && returned.provider == subscription.provider &&
        returned.subscription_reference == subscription.provider_subscription_id &&
        returned.customer_reference == subscription.customer_mapping.provider_customer_id &&
        returned.variant_reference == mapping.provider_variant_id
      return if valid

      raise ProviderFailure.new(
        provider: subscription.provider,
        operation: "change_subscription",
        category: "malformed_response",
        retryable: false
      )
    end

    def mark_submitted(change, subscription)
      return change.summary unless subscription

      event = nil
      summary = SubscriptionChange.transaction do
        locked = SubscriptionChange.lock.find(change.id)
        next locked.summary unless locked.state.in?(%w[pending scheduled])

        now = @clock.call
        locked.update!(state: "submitted", submitted_at: now, updated_at: now)
        @auditor.record!(
          organization_id: locked.organization_id,
          action: "billing.subscription_plan_change_submitted",
          target_type: "BillingPlanChange",
          target_id: locked.id,
          result: "succeeded",
          metadata: { direction: locked.direction, effective_policy: locked.effective_policy }
        )
        event = record_outbox(locked, "submitted")
        locked.summary
      end
      @outbox_enqueue.call(event) if event
      summary
    end

    def mark_failed(organization_id, change_id, category)
      SubscriptionChange.transaction do
        change = SubscriptionChange.lock.find_by!(id: change_id, organization_id: organization_id)
        return change.summary unless SubscriptionChange::ACTIVE_STATES.include?(change.state)

        now = @clock.call
        change.update!(
          state: "failed",
          failed_at: now,
          failure_category: safe_category(category),
          updated_at: now
        )
        @auditor.record!(
          organization_id: change.organization_id,
          action: "billing.subscription_plan_change_failed",
          target_type: "BillingPlanChange",
          target_id: change.id,
          result: "failed",
          metadata: { failure_category: change.failure_category }
        )
        change.summary
      end
    end

    def record_outbox(change, phase)
      @outbox.record_outbox_event!(
        organization_id: change.organization_id,
        aggregate_type: "BillingPlanChange",
        aggregate_id: change.id,
        event_type: "billing.subscription_plan_change_#{phase}",
        event_version: 1,
        payload: { "subscription_change_id" => change.id, "phase" => phase },
        idempotency_source: "billing-plan-change:#{change.id}:#{phase}",
        occurred_at: @clock.call
      ).id
    end

    def safe_category(value)
      category = value.to_s
      ValueNormalization::KEY_PATTERN.match?(category) ? category : "provider_failure"
    end
  end
end
