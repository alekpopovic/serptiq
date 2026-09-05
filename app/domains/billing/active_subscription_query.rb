# frozen_string_literal: true

module Billing
  class ActiveSubscriptionQuery
    def call(organization_id:)
      return unless Shared::Public.application_uuid?(organization_id)

      subscription = Subscription.current.find_by(organization_id: organization_id)
      return unless subscription

      SubscriptionSummary.new(
        id: subscription.id,
        organization_id: subscription.organization_id,
        plan_version_id: subscription.plan_version_id,
        status: subscription.status,
        access_state: subscription.access_state,
        billing_interval: subscription.billing_interval,
        plan_display_name: subscription.plan_display_name_snapshot,
        currency: subscription.currency_snapshot,
        pricing_kind: subscription.pricing_kind_snapshot,
        price_cents: subscription.price_cents_snapshot,
        started_at: subscription.started_at,
        ended_at: subscription.ended_at,
        current_period_starts_at: subscription.current_period_starts_at,
        current_period_ends_at: subscription.current_period_ends_at,
        cancel_at_period_end: subscription.cancel_at_period_end,
        provider_backed: subscription.provider_backed?
      )
    end
  end
end
