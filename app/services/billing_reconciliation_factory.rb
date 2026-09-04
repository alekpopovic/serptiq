# frozen_string_literal: true

class BillingReconciliationFactory
  class << self
    def requester(clock: -> { Time.current })
      Billing::RequestReconciliation.new(auditor: Auditing::Public, clock: clock)
    end

    def reconciler(settings: Rails.application.config.x.searchops, clock: -> { Time.current })
      registry = Billing::ProviderRegistry.new(settings: settings)
      Billing::ReconcileSubscription.new(
        provider_lookup: ->(key) { registry.fetch(key) },
        auditor: Auditing::Public,
        clock: clock
      )
    end

    def scheduler(clock: -> { Time.current })
      Billing::ScheduleReconciliations.new(requester: requester(clock: clock), clock: clock)
    end
  end
end
