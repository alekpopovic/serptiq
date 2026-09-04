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

    def portal_available?(organization_id:, provider:, environment: Rails.env.to_s)
      CustomerMapping.exists?(
        organization_id: organization_id,
        provider: provider.to_s,
        environment: environment.to_s
      ) && Subscription.current.exists?(organization_id: organization_id, provider: provider.to_s)
    end

    def active_checkout?(organization_id:, at: Time.current)
      CheckoutSession.active.where(organization_id: organization_id).where("expires_at > ?", at).exists?
    end

    def create_hosted_checkout(command:, **attributes)
      command.call(**attributes)
    end

    def create_customer_portal(command:, **attributes)
      command.call(**attributes)
    end

    def provider(provider_key:, registry: ProviderRegistry.new)
      registry.fetch(provider_key)
    end

    def operation_policies
      Provider::OPERATION_POLICIES
    end

    def register_customer_mapping(**attributes)
      RegisterCustomerMapping.new.call(**attributes)
    end

    def customer_mapping(**attributes)
      CustomerMappingLookup.new.call(**attributes)
    end

    def plan_mapping(**attributes)
      PlanMappingLookup.new.call(**attributes)
    end

    def receive_webhook(receiver: ReceiveWebhook.from_settings, **attributes)
      receiver.call(**attributes)
    end

    def webhook_events(**attributes)
      WebhookEventInventory.new.call(**attributes)
    end

    def prepare_webhook_projection(**attributes)
      process_webhook_event(**attributes)
    end

    def process_webhook_event(processor: WebhookProjectionJob.processor_builder.call, **attributes)
      processor.call(**attributes)
    end

    def replay_webhook_event(replayer:, **attributes)
      replayer.call(**attributes)
    end
  end
end
