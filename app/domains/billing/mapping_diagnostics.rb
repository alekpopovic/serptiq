# frozen_string_literal: true

module Billing
  class MappingDiagnostics
    def call(limit: 100)
      bounded = Integer(limit)
      raise ArgumentError, "billing mapping limit is invalid" unless bounded.between?(1, 200)

      subscriptions = Subscription.where.not(provider: nil).preload(:customer_mapping)
        .order(updated_at: :desc, id: :desc).limit(bounded).to_a
      available = PlanProviderMapping.where(plan_version_id: subscriptions.map(&:plan_version_id), active: true)
        .pluck(:plan_version_id, :provider, :environment, :currency, :billing_interval).to_set
      subscriptions.map do |subscription|
        reason = diagnostic_reason(subscription, available)
        MappingDiagnostic.new(
          organization_id: subscription.organization_id,
          subscription_id: subscription.id,
          provider: subscription.provider,
          environment: subscription.provider_environment,
          status: reason ? "invalid" : "valid",
          reason_code: reason || "mapping_complete"
        )
      end.freeze
    end

    private

    def diagnostic_reason(subscription, available)
      customer = subscription.customer_mapping
      return "customer_mapping_missing" unless customer
      return "customer_mapping_mismatch" unless customer.organization_id == subscription.organization_id &&
        customer.provider == subscription.provider && customer.environment == subscription.provider_environment

      key = [
        subscription.plan_version_id, subscription.provider, subscription.provider_environment,
        subscription.currency_snapshot, subscription.billing_interval
      ]
      "plan_mapping_missing" unless available.include?(key)
    end
  end
end
