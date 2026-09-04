# frozen_string_literal: true

module Billing
  class CreateSubscriptionReference
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, plan_version_id:, billing_interval:)
      Subscription.transaction do
        requested = Plans::Public.version_snapshot(id: plan_version_id)
        interval = billing_interval.to_s
        current = Plans::Public.purchasable_version(
          plan_key: requested.plan_key,
          currency: requested.currency,
          billing_interval: interval,
          at: @clock.call,
          lock: true
        )
        raise SubscriptionConflict.new(reason_code: "plan_version_not_purchasable") unless current.id == requested.id

        subscription = Subscription.create!(
          organization_id: organization_id,
          plan_version_id: current.id,
          status: "active",
          billing_interval: interval,
          plan_key_snapshot: current.plan_key,
          plan_version_snapshot: current.version,
          plan_display_name_snapshot: current.display_name,
          currency_snapshot: current.currency,
          pricing_kind_snapshot: current.pricing_kind,
          price_cents_snapshot: current.price_for(interval),
          started_at: @clock.call
        )
        Entitlements::Public.bind_subscription(
          organization_id: subscription.organization_id,
          subscription_id: subscription.id,
          plan_version_id: subscription.plan_version_id,
          subscription_revision: subscription.lock_version
        )
        subscription
      end
    rescue ArgumentError
      raise SubscriptionConflict.new(reason_code: "billing_interval_invalid"), cause: nil
    rescue Shared::Public::ConflictError
      raise SubscriptionConflict.new(reason_code: "plan_version_not_purchasable"), cause: nil
    rescue ActiveRecord::RecordInvalid => error
      if error.record.errors.of_kind?(:organization_id, :taken)
        raise SubscriptionConflict.new(reason_code: "active_subscription_exists"), cause: nil
      end

      raise
    rescue ActiveRecord::RecordNotUnique
      raise SubscriptionConflict.new(reason_code: "active_subscription_exists"), cause: nil
    end
  end
end
