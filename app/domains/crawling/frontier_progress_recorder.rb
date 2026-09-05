# frozen_string_literal: true

module Crawling
  class FrontierProgressRecorder
    def call(scan:, deltas:, operation_key:, occurred_at:)
      unknown = deltas.keys.map(&:to_sym) - ScanCounters.members
      raise ArgumentError, "unknown frontier progress counter" if unknown.any?

      attributes = scan.counters.to_h.dup
      deltas.each do |name, delta|
        key = name.to_sym
        attributes[key] += Integer(delta)
      end
      scan.assign_attributes(ScanCounters.new(**attributes).to_h)
      scan.progress_sequence += 1
      scan.save!
      _event, outbox = ScanLifecycleRecord.record!(
        scan: scan,
        event_type: "scan.progress_recorded",
        from_status: scan.status,
        actor_membership_id: nil,
        command: "frontier_progress",
        occurred_at: occurred_at,
        idempotency_source: "frontier-progress:#{scan.id}:#{operation_key}",
        audit: false
      )
      outbox
    end
  end
end
