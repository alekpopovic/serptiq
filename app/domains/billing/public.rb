# frozen_string_literal: true

module Billing
  module Public
    module_function

    def create_subscription_reference(**attributes)
      CreateSubscriptionReference.new.call(**attributes)
    end

    def active_subscriber_counts(plan_version_ids:)
      SubscriberCounts.new.call(plan_version_ids: plan_version_ids)
    end

    def active_subscriber_count(plan_version_id:)
      active_subscriber_counts(plan_version_ids: [ plan_version_id ]).fetch(plan_version_id.to_s, 0)
    end

    def plan_provider_mappings(active: nil)
      PlanProviderMappingInventory.new.call(active: active)
    end

    def active_subscription(organization_id:)
      ActiveSubscriptionQuery.new.call(organization_id: organization_id)
    end

    def checkout_available?(**attributes)
      CheckoutAvailability.new.call(**attributes)
    end
  end
end
