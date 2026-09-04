# frozen_string_literal: true

class BillingPlanChangeFactory
  def self.requester(settings: Rails.application.config.x.searchops, clock: -> { Time.current })
    provider_key = settings.fetch(:billing_provider).to_s
    raise Billing::ProviderUnknown.new(reason_code: "billing_provider_disabled") if provider_key == "disabled"

    provider = Billing::ProviderRegistry.new(settings: settings).fetch(provider_key)
    Billing::RequestSubscriptionPlanChange.new(
      provider: provider,
      environment: Rails.env.to_s,
      auditor: Auditing::Public,
      clock: clock
    )
  end

  def self.submitter(settings: Rails.application.config.x.searchops, clock: -> { Time.current })
    registry = Billing::ProviderRegistry.new(settings: settings)
    Billing::SubmitSubscriptionPlanChange.new(
      provider_lookup: ->(key) { registry.fetch(key) },
      auditor: Auditing::Public,
      clock: clock
    )
  end
end
