# frozen_string_literal: true

require "digest"

module Crawling
  class RecordScanProgress
    ACTIVE_PROGRESS_STATUSES = %w[queued running cancel_requested].freeze

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, scan_id:, counters:, checkpoint_key:)
      normalized = counters.is_a?(ScanCounters) ? counters : ScanCounters.new(**counters)
      key = checkpoint_key.to_s
      raise Conflict.new(reason_code: "scan_progress_key_invalid") unless key.bytesize.between?(8, 200)

      digest = Digest::SHA256.hexdigest("scan-progress:#{scan_id}:#{key}")
      scan = nil
      outbox = nil
      Scan.transaction do
        scan = Scan.lock.find_by!(organization_id: organization_id, id: scan_id)
        existing = ScanEvent.find_by(scan_id: scan.id, idempotency_key_digest: digest)
        if existing
          raise Conflict.new(reason_code: "scan_progress_replay_conflict") unless
            existing.counters.to_h == normalized.to_h

          return scan
        end
        raise Conflict.new(reason_code: "scan_progress_state_invalid") unless
          scan.status.in?(ACTIVE_PROGRESS_STATUSES)
        raise Conflict.new(reason_code: "scan_progress_regressed") unless normalized.monotonic_from?(scan.counters)

        scan.assign_attributes(normalized.to_h)
        scan.progress_sequence += 1
        scan.save!
        _event, outbox = ScanLifecycleRecord.record!(
          scan: scan,
          event_type: "scan.progress_recorded",
          from_status: scan.status,
          actor_membership_id: nil,
          command: "record_progress",
          occurred_at: @clock.call,
          idempotency_source: "scan-progress:#{scan.id}:#{key}",
          audit: false
        )
      end
      ScanLifecycleRecord.enqueue(outbox)
      scan
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_scope_unavailable"), cause: nil
    rescue ArgumentError => error
      raise Conflict.new(reason_code: "scan_progress_invalid"), cause: error
    end
  end
end
