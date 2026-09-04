# frozen_string_literal: true

module Billing
  class ReplayWebhookEvent
    REPLAYABLE_STATES = %w[retryable dead_letter].freeze

    def initialize(auditor:, clock: -> { Time.current },
      enqueue: ->(id) { WebhookProjectionJob.perform_later(webhook_event_id: id) })
      @clock = clock
      @enqueue = enqueue
      @auditor = auditor
    end

    def call(webhook_event_id:, confirmation:)
      event = WebhookEvent.transaction do
        record = WebhookEvent.lock.find(webhook_event_id)
        unless REPLAYABLE_STATES.include?(record.state) && confirmation.to_s == "REPLAY #{record.id}"
          raise WebhookProjectionFailure.new(category: "replay_not_authorized", retryable: false)
        end
        record.prepare_replay!(at: @clock.call)
        @auditor.record!(
          organization_id: record.organization_id,
          action: "billing.webhook_replayed",
          target_type: "BillingWebhook",
          target_id: record.id,
          result: "succeeded",
          metadata: { provider: record.provider, state: record.state }
        )
        record
      end
      @enqueue.call(event.id)
      event.summary
    rescue WebhookEnqueueFailure
      raise
    rescue StandardError => error
      raise error if error.is_a?(WebhookProjectionFailure)

      Rails.error.report(error, handled: true, severity: :error,
        context: { "operation" => "replay_billing_webhook" })
      raise WebhookEnqueueFailure, cause: nil
    end
  end
end
