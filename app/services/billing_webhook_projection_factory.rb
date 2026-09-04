# frozen_string_literal: true

class BillingWebhookProjectionFactory
  def self.build(clock: -> { Time.current })
    Billing::ProcessWebhookEvent.new(
      clock: clock,
      projector: Billing::ProjectProviderEvent.new(clock: clock, auditor: Auditing::Public)
    )
  end

  def self.replayer(clock: -> { Time.current }, enqueue: nil)
    attributes = { clock: clock, auditor: Auditing::Public }
    attributes[:enqueue] = enqueue if enqueue
    Billing::ReplayWebhookEvent.new(**attributes)
  end
end
