# frozen_string_literal: true

module Billing
  class ProcessWebhookEvent
    CURRENT_PARSER_VERSION = 1
    MAX_ATTEMPTS = 5
    RETRY_DELAYS = [ 1.minute, 5.minutes, 30.minutes, 2.hours ].freeze

    def initialize(projector:, clock: -> { Time.current }, provider_lookup: nil,
      outbox_enqueue: ->(id) { Shared::Public.enqueue_outbox_event!(outbox_event_id: id) })
      @clock = clock
      @provider_lookup = provider_lookup || ->(key) { Public.provider(provider_key: key) }
      @projector = projector
      @outbox_enqueue = outbox_enqueue
    end

    def call(webhook_event_id:)
      outcome = process(webhook_event_id)
      enqueue_outbox(outcome)
      instrument(outcome.result, "projection_complete")
      outcome
    rescue WebhookProjectionFailure => error
      retryable = record_failure(webhook_event_id, error)
      instrument(retryable ? "retrying" : "failed", error.category)
      raise WebhookProjectionRetry if retryable

      WebhookEvent.find(webhook_event_id).summary
    rescue StandardError => error
      Rails.error.report(
        error, handled: true, severity: :error,
        context: { "billing_webhook_event_id" => safe_id(webhook_event_id) }
      )
      failure = WebhookProjectionFailure.new(category: "internal_failure", retryable: true)
      retryable = record_failure(webhook_event_id, failure)
      instrument(retryable ? "retrying" : "failed", failure.category)
      raise WebhookProjectionRetry if retryable

      WebhookEvent.find(webhook_event_id).summary
    end

    private

    def process(webhook_event_id)
      WebhookEvent.transaction do
        event = WebhookEvent.lock.find(webhook_event_id)
        return existing_outcome(event) unless %w[pending retryable].include?(event.state)

        event.begin_attempt!(at: @clock.call)
        unless event.parser_version == CURRENT_PARSER_VERSION
          raise WebhookProjectionFailure.new(category: "parser_version_unsupported", retryable: false)
        end
        verified = VerifiedWebhook.new(
          provider: event.provider,
          raw_body: event.payload,
          received_at: event.received_at
        )
        provider_event = @provider_lookup.call(event.provider).parse_event(webhook: verified)
        outcome = @projector.call(webhook_event: event, provider_event: provider_event)
        event.complete_projection!(
          result: outcome.result,
          at: @clock.call,
          organization_id: outcome.organization_id,
          subscription_id: outcome.subscription_id
        )
        outcome
      rescue ProviderFailure => error
        if error.category == "unsupported_event"
          outcome = WebhookProjectionOutcome.new(result: "ignored")
          event.complete_projection!(result: outcome.result, at: @clock.call)
          outcome
        else
          raise WebhookProjectionFailure.new(
            category: "provider_#{error.category}", retryable: error.retryable?
          )
        end
      rescue ProviderMappingMissing => error
        raise WebhookProjectionFailure.new(category: error.reason_code, retryable: true)
      rescue WebhookPayloadCorrupt
        raise WebhookProjectionFailure.new(category: "payload_corrupt", retryable: false)
      end
    end

    def existing_outcome(event)
      result = event.processing_result || (event.state == "dead_letter" ? "ignored" : "stale")
      WebhookProjectionOutcome.new(
        result: result,
        organization_id: event.organization_id,
        subscription_id: event.subscription_id,
        canonical_changed: false
      )
    end

    def record_failure(webhook_event_id, failure)
      WebhookEvent.transaction do
        event = WebhookEvent.lock.find(webhook_event_id)
        return false if event.state == "processed"

        event.begin_attempt!(at: @clock.call) unless event.state == "processing"
        retryable = failure.retryable? && event.attempt_count < MAX_ATTEMPTS
        retry_at = @clock.call + retry_delay(event.attempt_count) if retryable
        event.fail_projection!(
          category: failure.category,
          retryable: retryable,
          retry_at: retry_at,
          at: @clock.call
        )
        retryable
      end
    end

    def retry_delay(attempt_count)
      RETRY_DELAYS.fetch([ attempt_count - 1, RETRY_DELAYS.length - 1 ].min)
    end

    def instrument(result, reason_code)
      outcome = case result.to_s
      when "retrying" then "retrying"
      when "failed" then "failed"
      when "ignored", "stale" then "ignored"
      else "succeeded"
      end
      Shared::Public.emit_structured_event(
        "billing.webhook_projection",
        outcome: outcome,
        operation: "project_webhook",
        reason_code: reason_code
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "billing.webhook_projection")
    end

    def safe_id(value)
      candidate = value.to_s
      Shared::Public.application_uuid?(candidate) ? candidate : nil
    end

    def enqueue_outbox(outcome)
      outcome.outbox_event_ids.each { |id| @outbox_enqueue.call(id) }
    rescue StandardError => error
      Rails.error.report(error, handled: true, severity: :error,
        context: { "operation" => "billing_outbox_enqueue" })
    end
  end
end
