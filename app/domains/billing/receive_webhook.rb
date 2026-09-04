# frozen_string_literal: true

require "digest"

module Billing
  class ReceiveWebhook
    ACTIONABLE_STATES = %w[pending retryable].freeze

    def self.from_settings(settings: Rails.application.config.x.searchops,
      registry: ProviderRegistry.new(settings: settings))
      provider_key = settings.fetch(:billing_provider).to_s
      unless provider_key == "lemon_squeezy"
        raise ProviderUnknown.new(reason_code: "billing_webhook_provider_unavailable")
      end

      new(provider: registry.fetch(provider_key), environment: Rails.env.to_s)
    end

    def initialize(provider:, environment:, clock: -> { Time.current }, cipher: WebhookPayloadCipher.new,
      header_filter: WebhookRequestHeaders.new,
      enqueue: ->(id) { WebhookProjectionJob.perform_later(webhook_event_id: id) })
      @provider = provider
      @environment = ValueNormalization.string!(environment, name: "environment", maximum: 16)
      raise ArgumentError, "billing environment is invalid" unless WebhookEvent::ENVIRONMENTS.include?(@environment)

      @clock = clock
      @cipher = cipher
      @header_filter = header_filter
      @enqueue = enqueue
    end

    def call(raw_body:, headers:)
      verified = @provider.verify_webhook(raw_body: raw_body, headers: headers)
      provider_event = @provider.parse_event(webhook: verified)
      checksum = Digest::SHA256.hexdigest(verified.raw_body)
      safe_headers = @header_filter.call(headers: headers, body_bytes: verified.raw_body.bytesize)
      ciphertext = @cipher.encrypt(verified.raw_body)
      record, status = persist(
        provider_event: provider_event,
        checksum: checksum,
        ciphertext: ciphertext,
        safe_headers: safe_headers,
        received_at: verified.received_at
      )
      enqueue(record) if status != "conflict" && ACTIONABLE_STATES.include?(record.state)
      WebhookReceipt.new(id: record.id, status: status, event_type: record.event_type)
    end

    private

    def persist(provider_event:, checksum:, ciphertext:, safe_headers:, received_at:)
      record = nil
      status = nil
      WebhookEvent.transaction do
        record = WebhookEvent.create_or_find_by!(
          provider: provider_event.provider,
          environment: @environment,
          provider_event_id: provider_event.reference
        ) do |candidate|
          candidate.assign_attributes(
            event_type: provider_event.name,
            payload_checksum: checksum,
            payload_ciphertext: ciphertext,
            request_headers: safe_headers,
            state: "pending",
            received_at: received_at,
            last_received_at: received_at
          )
        end
        created = record.previously_new_record?
        record.lock!
        status = created ? "accepted" : register_duplicate(record, provider_event, checksum, received_at)
      end
      [ record, status ]
    end

    def register_duplicate(record, provider_event, checksum, received_at)
      if record.payload_checksum == checksum && record.event_type == provider_event.name
        record.update!(
          duplicate_count: record.duplicate_count + 1,
          last_received_at: [ record.last_received_at, received_at ].max
        )
        "duplicate"
      else
        record.update!(
          conflict_count: record.conflict_count + 1,
          last_received_at: [ record.last_received_at, received_at ].max
        )
        "conflict"
      end
    end

    def enqueue(record)
      @enqueue.call(record.id)
    rescue StandardError => error
      Rails.error.report(
        error,
        handled: true,
        severity: :error,
        context: { "billing_webhook_event_id" => record.id }
      )
      raise WebhookEnqueueFailure, cause: nil
    end
  end
end
