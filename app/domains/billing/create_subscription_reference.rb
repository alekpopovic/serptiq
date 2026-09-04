# frozen_string_literal: true

module Billing
  class CreateSubscriptionReference
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, plan_version_id:, billing_interval:)
      snapshot = Plans::Public.version_snapshot(id: plan_version_id)
      raise SubscriptionConflict.new(reason_code: "plan_version_not_published") unless snapshot.status == "published"

      interval = billing_interval.to_s
      price = snapshot.price_for(interval)
      Subscription.create!(
        organization_id: organization_id,
        plan_version_id: snapshot.id,
        status: "active",
        billing_interval: interval,
        plan_key_snapshot: snapshot.plan_key,
        plan_version_snapshot: snapshot.version,
        plan_display_name_snapshot: snapshot.display_name,
        currency_snapshot: snapshot.currency,
        pricing_kind_snapshot: snapshot.pricing_kind,
        price_cents_snapshot: price,
        started_at: @clock.call
      )
    rescue ArgumentError
      raise SubscriptionConflict.new(reason_code: "billing_interval_invalid"), cause: nil
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
