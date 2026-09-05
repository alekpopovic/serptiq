# frozen_string_literal: true

require "digest"

module Crawling
  module ScanLifecycleRecord
    module_function

    def record!(scan:, event_type:, from_status:, actor_membership_id:, command:, occurred_at:,
      idempotency_source: nil, audit: true)
      source = idempotency_source || "#{event_type}:#{scan.id}:#{scan.progress_sequence}"
      payload = event_payload(scan, event_type, from_status)
      event = ScanEvent.create!(
        **scan_identity(scan),
        sequence: scan.progress_sequence,
        event_type: event_type,
        from_status: from_status,
        to_status: scan.status,
        actor_membership_id: actor_membership_id,
        idempotency_key_digest: Digest::SHA256.hexdigest(source),
        payload_digest: Digest::SHA256.hexdigest(JSON.generate(payload.sort.to_h)),
        **scan.counters.to_h,
        failure_category: scan.failure_category,
        occurred_at: occurred_at,
        created_at: occurred_at
      )
      record_audit!(scan, event_type, from_status, actor_membership_id, command) if audit
      outbox = Shared::Public.record_outbox_event!(
        organization_id: scan.organization_id,
        aggregate_type: "Scan",
        aggregate_id: scan.id,
        event_type: event_type,
        event_version: 1,
        payload: payload,
        idempotency_source: source,
        occurred_at: occurred_at
      )
      [ event, outbox ]
    end

    def enqueue(outbox_event)
      Shared::Public.enqueue_outbox_event!(outbox_event_id: outbox_event.id)
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "scan.outbox_enqueue_failed")
    end

    def event_payload(scan, event_type, from_status)
      {
        "scan_id" => scan.id,
        "organization_id" => scan.organization_id,
        "project_id" => scan.project_id,
        "property_id" => scan.property_id,
        "environment_id" => scan.environment_id,
        "scan_type" => scan.scan_type,
        "event_type" => event_type,
        "from_status" => from_status,
        "status" => scan.status,
        "progress_sequence" => scan.progress_sequence,
        "failure_category" => scan.failure_category
      }.compact.freeze
    end

    def scan_identity(scan)
      {
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        scan_id: scan.id
      }
    end

    def record_audit!(scan, event_type, from_status, actor_membership_id, command)
      Auditing::Public.record!(
        organization_id: scan.organization_id,
        actor_membership_id: actor_membership_id,
        action: event_type,
        target_type: "Scan",
        target_id: scan.id,
        result: "succeeded",
        metadata: {
          operation: command,
          from_status: from_status,
          status: scan.status,
          scan_type: scan.scan_type
        }.compact
      )
    end
  end
end
