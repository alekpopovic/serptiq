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
  end
end
