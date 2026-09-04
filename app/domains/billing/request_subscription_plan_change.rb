# frozen_string_literal: true

require "digest"
require "openssl"

module Billing
  class RequestSubscriptionPlanChange
    def initialize(provider:, environment:, auditor:, clock: -> { Time.current },
      digest_secret: Rails.application.secret_key_base, outbox: Shared::Public,
      enqueue: ->(organization_id, subscription_change_id, effective_at) {
        SubscriptionPlanChangeJob.set(wait_until: effective_at).perform_later(
          organization_id: organization_id,
          subscription_change_id: subscription_change_id
        )
      }, outbox_enqueue: ->(id) {
        Shared::Public.enqueue_outbox_event!(outbox_event_id: id)
      })
      @provider = provider
      @environment = environment.to_s
      @auditor = auditor
      @clock = clock
      @digest_secret = digest_secret.to_s
      @outbox = outbox
      @enqueue = enqueue
      @outbox_enqueue = outbox_enqueue
    end

    def call(actor_membership:, organization:, target_plan_key:, target_plan_version_id:,
      currency:, billing_interval:, request_key:, authorization:)
      tenant = AuthorizeManagement.new.call(
        actor_membership: actor_membership,
        organization: organization,
        authorization: authorization
      )
      now = @clock.call
      digest = request_digest(request_key)
      existing = SubscriptionChange.find_by(organization_id: tenant.id, idempotency_digest: digest)
      if existing
        summary = idempotent_result(existing, target_plan_version_id, billing_interval)
        dispatch(existing, existing_outbox(existing))
        return summary
      end

      change, outbox_event = SubscriptionChange.transaction do
        subscription = Subscription.current.lock.find_by!(organization_id: tenant.id)
        validate_subscription!(subscription, now)
        target = Plans::Public.plan_change_target(
          current_plan_version_id: subscription.plan_version_id,
          target_plan_key: target_plan_key,
          currency: currency,
          billing_interval: billing_interval,
          at: now
        )
        unless target.version.id == target_plan_version_id.to_s && target.direction.in?(SubscriptionChange::DIRECTIONS)
          raise PlanChangeConflict.new(reason_code: "billing_plan_change_target_invalid")
        end
        Billing::Public.plan_mapping(
          plan_version_id: target.version.id,
          provider: @provider.provider_key,
          environment: @environment,
          currency: currency,
          billing_interval: billing_interval
        )
        effective_at = effective_at(subscription, target, now)
        attributes = change_attributes(
          subscription, target, actor_membership, billing_interval, digest, now, effective_at
        )
        checksum = request_checksum(attributes)
        record = SubscriptionChange.create!(**attributes, request_checksum: checksum)
        audit_request(record, actor_membership)
        event = record_outbox(record, "billing.subscription_plan_change_requested", "requested")
        [ record, event ]
      end
      dispatch(change, outbox_event)
      change.summary
    rescue Plans::Public::CatalogTargetUnavailable, ProviderMappingMissing, ActiveRecord::RecordNotFound => error
      raise PlanChangeConflict.new(reason_code: "billing_plan_change_unavailable"), cause: error
    rescue ActiveRecord::RecordNotUnique
      existing = SubscriptionChange.find_by(organization_id: tenant.id, idempotency_digest: digest)
      if existing
        summary = idempotent_result(existing, target_plan_version_id, billing_interval)
        dispatch(existing, existing_outbox(existing))
        return summary
      end

      raise PlanChangeConflict.new(reason_code: "billing_plan_change_in_progress"), cause: nil
    end

    private

    def validate_subscription!(subscription, now)
      valid = subscription.provider_backed? && subscription.provider == @provider.provider_key &&
        subscription.provider_environment == @environment &&
        subscription.effective_access_state(at: now).in?(%w[full grace]) &&
        !SubscriptionChange.active.exists?(subscription_id: subscription.id)
      raise PlanChangeConflict.new(reason_code: "billing_plan_change_unavailable") unless valid
    end

    def effective_at(subscription, target, now)
      return now if target.effective_policy == "immediate"
      ending = subscription.current_period_ends_at
      unless ending && ending > now
        raise PlanChangeConflict.new(reason_code: "billing_plan_change_period_missing")
      end

      ending
    end

    def change_attributes(subscription, target, actor, interval, digest, now, effective_at)
      {
        organization_id: subscription.organization_id,
        subscription_id: subscription.id,
        from_plan_version_id: subscription.plan_version_id,
        target_plan_version_id: target.version.id,
        requested_by_membership_id: actor.id,
        target_billing_interval: interval.to_s,
        direction: target.direction,
        effective_policy: target.effective_policy,
        state: target.effective_policy == "immediate" ? "pending" : "scheduled",
        idempotency_digest: digest,
        requested_at: now,
        effective_at: effective_at,
        created_at: now,
        updated_at: now
      }
    end

    def request_digest(value)
      key = ValueNormalization.string!(value, name: "plan change request key", maximum: 200)
      OpenSSL::HMAC.hexdigest("SHA256", @digest_secret, key)
    end

    def request_checksum(attributes)
      values = %w[
        organization_id subscription_id from_plan_version_id target_plan_version_id
        target_billing_interval direction effective_policy
      ].map { |key| attributes[key] || attributes[key.to_sym] }
      Digest::SHA256.hexdigest(values.join("\0"))
    end

    def idempotent_result(existing, target_plan_version_id, billing_interval)
      raise PlanChangeConflict.new(reason_code: "billing_plan_change_request_conflict") unless
        existing && existing.target_plan_version_id == target_plan_version_id.to_s &&
          existing.target_billing_interval == billing_interval.to_s

      existing.summary
    end

    def dispatch(change, outbox_event)
      unless change.dispatch_enqueued_at
        @enqueue.call(change.organization_id, change.id, change.effective_at)
        change.with_lock do
          change.update!(dispatch_enqueued_at: @clock.call) unless change.dispatch_enqueued_at
        end
      end
      @outbox_enqueue.call(outbox_event) if outbox_event
    rescue StandardError
      raise PlanChangeRetry
    end

    def existing_outbox(change)
      Shared::Public.unpublished_outbox_event_id(
        aggregate_type: "BillingPlanChange",
        aggregate_id: change.id,
        event_type: "billing.subscription_plan_change_requested"
      )
    end

    def audit_request(change, actor)
      @auditor.record!(
        organization_id: change.organization_id,
        actor_membership_id: actor.id,
        action: "billing.subscription_plan_change_requested",
        target_type: "BillingPlanChange",
        target_id: change.id,
        result: "succeeded",
        metadata: {
          direction: change.direction,
          effective_policy: change.effective_policy,
          state: change.state,
          effective_at: change.effective_at.iso8601
        }
      )
    end

    def record_outbox(change, type, phase)
      @outbox.record_outbox_event!(
        organization_id: change.organization_id,
        aggregate_type: "BillingPlanChange",
        aggregate_id: change.id,
        event_type: type,
        event_version: 1,
        payload: {
          "subscription_change_id" => change.id,
          "direction" => change.direction,
          "effective_policy" => change.effective_policy,
          "phase" => phase,
          "effective_at" => change.effective_at.iso8601
        },
        idempotency_source: "billing-plan-change:#{change.id}:#{phase}",
        occurred_at: @clock.call
      ).id
    end
  end
end
