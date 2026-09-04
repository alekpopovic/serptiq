# frozen_string_literal: true

require "digest"

module Billing
  class ProjectProviderEvent
    SUBSCRIPTION_PRECEDENCE = {
      "trialing" => 40, "active" => 40, "pending" => 50, "incomplete" => 50, "canceled" => 60,
      "paused" => 70, "past_due" => 80, "expired" => 100
    }.freeze
    CORRELATION_KEYS = %w[organization_id plan_version_id checkout_session_id correlation].freeze
    ENTITLEMENT_FIELDS = %w[
      plan_version_id status access_state billing_interval current_period_starts_at
      current_period_ends_at trial_ends_at cancel_at_period_end grace_ends_at
      access_expires_at ended_at
    ].freeze

    def initialize(auditor:, clock: -> { Time.current }, correlation: CheckoutCorrelation.new,
      outbox: Shared::Public)
      @clock = clock
      @correlation = correlation
      @auditor = auditor
      @outbox = outbox
    end

    def call(webhook_event:, provider_event:)
      customer = customer_mapping!(webhook_event, provider_event)
      correlation_plan_id = validate_correlation!(webhook_event, provider_event, customer)
      if provider_event.subscription_snapshot
        project_subscription(webhook_event, provider_event, customer, correlation_plan_id)
      else
        observe_event(webhook_event, provider_event, customer)
      end
    end

    private

    def customer_mapping!(webhook_event, provider_event)
      reference = provider_event.customer_reference
      failure!("customer_reference_missing", retryable: false) if reference.blank?
      mapping = CustomerMapping.lock.find_by(
        provider: webhook_event.provider,
        environment: webhook_event.environment,
        provider_customer_id: reference
      )
      failure!("customer_mapping_missing", retryable: true) unless mapping
      mapping
    end

    def validate_correlation!(webhook_event, provider_event, customer)
      metadata = provider_event.metadata
      supplied = CORRELATION_KEYS.select { |key| metadata.key?(key) }
      return if supplied.empty?
      failure!("checkout_correlation_incomplete", retryable: false) unless supplied.sort == CORRELATION_KEYS.sort

      session = CheckoutSession.lock.find_by(id: metadata.fetch("checkout_session_id"))
      failure!("checkout_correlation_missing", retryable: true) unless session
      valid = session.organization_id == customer.organization_id &&
        session.plan_version_id == metadata.fetch("plan_version_id") &&
        session.organization_id == metadata.fetch("organization_id") &&
        session.provider == webhook_event.provider && session.environment == webhook_event.environment &&
        session.billing_customer_id == customer.id &&
        @correlation.valid?(
          signature: metadata.fetch("correlation"),
          organization_id: session.organization_id,
          plan_version_id: session.plan_version_id,
          checkout_session_id: session.id,
          environment: session.environment
        )
      failure!("checkout_correlation_invalid", retryable: false) unless valid
      session.plan_version_id
    end

    def project_subscription(webhook_event, provider_event, customer, correlation_plan_id)
      snapshot = provider_event.subscription_snapshot
      mapping = plan_mapping!(webhook_event, snapshot)
      if correlation_plan_id && correlation_plan_id != mapping.plan_version_id
        failure!("checkout_plan_mapping_conflict", retryable: false)
      end
      plan = Plans::Public.version_snapshot(id: mapping.plan_version_id, lock: true)
      subscription = Subscription.lock.find_by(
        provider: webhook_event.provider,
        provider_environment: webhook_event.environment,
        provider_subscription_id: snapshot.subscription_reference
      )
      if subscription && subscription.organization_id != customer.organization_id
        failure!("subscription_tenant_conflict", retryable: false)
      end
      subscription ||= new_subscription!(webhook_event, snapshot, customer)

      precedence = SUBSCRIPTION_PRECEDENCE.fetch(snapshot.status)
      if stale?(subscription, snapshot.provider_updated_at, precedence)
        audit(webhook_event, subscription, "ignored", "stale")
        return outcome("stale", subscription, changed: false)
      end

      new_record = subscription.new_record?
      transition = SubscriptionLifecycle.transition(
        from: new_record ? nil : subscription.status,
        snapshot: snapshot,
        at: @clock.call,
        current_grace_ends_at: subscription.grace_ends_at
      )
      change = pending_plan_change(subscription, mapping, snapshot)
      subscription.assign_attributes(subscription_attributes(
        webhook_event, provider_event, snapshot, transition, customer, mapping, plan, precedence
      ))
      entitlement_changed = new_record || (subscription.changes.keys & ENTITLEMENT_FIELDS).any?
      subscription.save!
      outbox_event_ids = []
      if change
        apply_plan_change(change, snapshot)
        outbox_event_ids << record_plan_change_outbox(change)
      elsif snapshot.status == "expired"
        cancel_pending_plan_change(subscription)
      end
      if entitlement_changed
        Entitlements::Public.bind_subscription(
          organization_id: subscription.organization_id,
          subscription_id: subscription.id,
          plan_version_id: subscription.plan_version_id,
          subscription_revision: subscription.lock_version,
          subscription_status: subscription.status,
          access_state: subscription.access_state,
          grace_ends_at: subscription.grace_ends_at,
          access_expires_at: subscription.access_expires_at,
          active: true
        )
        outbox_event_ids << record_lifecycle_outbox(subscription, webhook_event)
      end
      audit(webhook_event, subscription, "succeeded", "applied")
      outcome(
        "applied", subscription, changed: entitlement_changed,
        outbox_event_ids: outbox_event_ids
      )
    rescue ActiveRecord::RecordNotUnique
      failure!("subscription_identity_conflict", retryable: true)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey => error
      raise WebhookProjectionFailure.new(
        category: "subscription_projection_invalid", retryable: false
      ), cause: error
    rescue SubscriptionTransitionInvalid
      failure!("subscription_transition_invalid", retryable: false)
    rescue Shared::Public::ConflictError, ActiveRecord::RecordNotFound
      failure!("plan_mapping_invalid", retryable: false)
    end

    def new_subscription!(webhook_event, snapshot, customer)
      current = Subscription.current.lock.find_by(organization_id: customer.organization_id)
      failure!("subscription_current_conflict", retryable: false) if current
      Subscription.new(
        organization_id: customer.organization_id,
        provider: webhook_event.provider,
        provider_environment: webhook_event.environment,
        provider_subscription_id: snapshot.subscription_reference
      )
    end

    def plan_mapping!(webhook_event, snapshot)
      mapping = PlanProviderMapping.lock.find_by(
        provider: webhook_event.provider,
        environment: webhook_event.environment,
        provider_variant_id: snapshot.variant_reference,
        active: true
      )
      failure!("plan_mapping_missing", retryable: true) unless mapping
      mapping
    end

    def stale?(subscription, event_time, precedence)
      return false unless subscription.persisted? && subscription.provider_updated_at
      return true if event_time < subscription.provider_updated_at

      event_time == subscription.provider_updated_at && precedence <= subscription.provider_event_precedence
    end

    def subscription_attributes(webhook_event, provider_event, snapshot, transition, customer, mapping, plan, precedence)
      {
        billing_customer_id: customer.id,
        plan_version_id: plan.id,
        plan_key_snapshot: plan.plan_key,
        plan_version_snapshot: plan.version,
        plan_display_name_snapshot: plan.display_name,
        currency_snapshot: mapping.currency,
        pricing_kind_snapshot: plan.pricing_kind,
        price_cents_snapshot: plan.price_for(mapping.billing_interval),
        billing_interval: mapping.billing_interval,
        status: transition.status,
        access_state: transition.access_state,
        started_at: snapshot.started_at,
        grace_ends_at: transition.grace_ends_at,
        access_expires_at: transition.access_expires_at,
        ended_at: transition.ended_at,
        current_period_starts_at: snapshot.current_period_starts_at,
        current_period_ends_at: snapshot.current_period_ends_at,
        trial_ends_at: snapshot.trial_ends_at,
        cancel_at_period_end: snapshot.cancel_at_period_end,
        canceled_at: snapshot.canceled_at,
        provider_updated_at: snapshot.provider_updated_at,
        last_synced_at: @clock.call,
        provider_metadata: snapshot.metadata.merge("last_event" => provider_event.name),
        provider_event_precedence: precedence,
        provider_event_digest: Digest::SHA256.hexdigest(webhook_event.provider_event_id)
      }
    end

    def observe_event(webhook_event, provider_event, customer)
      subscription = nil
      if provider_event.subscription_reference
        subscription = Subscription.lock.find_by(
          provider: webhook_event.provider,
          provider_environment: webhook_event.environment,
          provider_subscription_id: provider_event.subscription_reference,
          organization_id: customer.organization_id
        )
        failure!("subscription_mapping_missing", retryable: true) unless subscription
      end
      audit(webhook_event, subscription, "succeeded", "observed", organization_id: customer.organization_id)
      WebhookProjectionOutcome.new(
        result: "observed",
        organization_id: customer.organization_id,
        subscription_id: subscription&.id,
        canonical_changed: false
      )
    end

    def outcome(result, subscription, changed:, outbox_event_ids: [])
      WebhookProjectionOutcome.new(
        result: result,
        organization_id: subscription.organization_id,
        subscription_id: subscription.id,
        canonical_changed: changed,
        outbox_event_ids: outbox_event_ids
      )
    end

    def pending_plan_change(subscription, mapping, snapshot)
      return if subscription.new_record?

      change = SubscriptionChange.active.lock.find_by(subscription_id: subscription.id)
      return unless change && change.target_plan_version_id == mapping.plan_version_id
      if change.effective_policy == "period_end" && snapshot.provider_updated_at < change.effective_at
        failure!("scheduled_plan_change_early", retryable: true)
      end
      change
    end

    def apply_plan_change(change, snapshot)
      applied_at = @clock.call
      change.update!(
        state: "applied",
        submitted_at: change.submitted_at || snapshot.provider_updated_at,
        applied_at: applied_at,
        updated_at: applied_at
      )
      @auditor.record!(
        organization_id: change.organization_id,
        action: "billing.subscription_plan_change_applied",
        target_type: "BillingPlanChange",
        target_id: change.id,
        result: "succeeded",
        metadata: { direction: change.direction, effective_policy: change.effective_policy }
      )
    end

    def cancel_pending_plan_change(subscription)
      change = SubscriptionChange.active.lock.find_by(subscription_id: subscription.id)
      change&.update!(state: "canceled", updated_at: @clock.call)
    end

    def record_plan_change_outbox(change)
      @outbox.record_outbox_event!(
        organization_id: change.organization_id,
        aggregate_type: "BillingPlanChange",
        aggregate_id: change.id,
        event_type: "billing.subscription_plan_change_applied",
        event_version: 1,
        payload: {
          "subscription_change_id" => change.id,
          "direction" => change.direction,
          "phase" => "applied"
        },
        idempotency_source: "billing-plan-change:#{change.id}:applied",
        occurred_at: @clock.call
      ).id
    end

    def record_lifecycle_outbox(subscription, webhook_event)
      @outbox.record_outbox_event!(
        organization_id: subscription.organization_id,
        aggregate_type: "BillingSubscription",
        aggregate_id: subscription.id,
        event_type: "billing.subscription_access_changed",
        event_version: 1,
        payload: {
          "subscription_id" => subscription.id,
          "status" => subscription.status,
          "access_state" => subscription.access_state,
          "plan_version_id" => subscription.plan_version_id
        },
        idempotency_source: "billing-subscription:#{subscription.id}:webhook:#{webhook_event.id}",
        occurred_at: @clock.call
      ).id
    end

    def audit(webhook_event, subscription, result, projection_result, organization_id: nil)
      @auditor.record!(
        organization_id: organization_id || subscription&.organization_id,
        action: subscription ? "billing.subscription_projected" : "billing.provider_event_observed",
        target_type: subscription ? "BillingSubscription" : "BillingWebhook",
        target_id: subscription&.id || webhook_event.id,
        result: result,
        metadata: {
          provider: webhook_event.provider,
          event_type: webhook_event.event_type,
          projection_result: projection_result,
          status: subscription&.status,
          access_state: subscription&.access_state
        }.compact
      )
    end

    def failure!(category, retryable:)
      raise WebhookProjectionFailure.new(category: category, retryable: retryable)
    end
  end
end
