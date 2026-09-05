# frozen_string_literal: true

module Crawling
  class FinalizeScanUsage
    def initialize(clock: -> { Time.current }, identity: ScanUsageIdentity.new)
      @clock = clock
      @identity = identity
    end

    def call(organization_id:, scan_id:, at: @clock.call)
      Scan.transaction do
        scan = Scan.lock.find_by!(id: scan_id, organization_id: organization_id)
        raise Conflict.new(reason_code: "scan_usage_terminal_required") unless scan.terminal?

        call_locked(scan: scan, at: at)
      end
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_scope_unavailable"), cause: nil
    end

    def call_locked(scan:, at: @clock.call)
      return scan unless scan.usage_quota_reservation_id

      now = validate_time!(at)
      release_pending!(scan, now)
      reservation = scan.quota_reservation.reload
      if reservation.held?
        Authorization::Public.finalize_metered_access(
          organization_id: scan.organization_id,
          reservation_id: reservation.id,
          idempotency_key: "scan-usage-terminal:#{scan.id}",
          actual_billed_quantity: reservation.consumed_quantity,
          occurred_at: scan.finished_at || now,
          at: now,
          metadata: {
            "scan_id" => scan.id,
            "terminal_status" => scan.status,
            "accounting" => "incremental_operations"
          }
        )
      end
      scan
    end

    private

    def release_pending!(scan, now)
      scan.usage_operations.pending.lock.order(:id).each do |operation|
        metadata = operation.metadata.merge("recovery_reason" => "terminal_scan")
        if operation.usage_quota_allocation_id
          allocation = operation.quota_allocation.reload
          if allocation.held?
            Usage::Public.release_allocation(
              clock: -> { now },
              organization_id: scan.organization_id,
              allocation_id: operation.usage_quota_allocation_id,
              idempotency_key: "scan-usage-terminal-release:#{operation.source_key_digest}",
              occurred_at: now,
              at: now,
              metadata: {
                "scan_id" => scan.id,
                "operation" => operation.operation_kind,
                "reason" => "terminal_recovery"
              }
            )
          end
        end
        operation.update!(
          state: "not_billable",
          outcome: "abandoned",
          completion_checksum: @identity.checksum(
            operation_id: operation.id,
            outcome: "abandoned",
            occurred_at: now,
            metadata: metadata
          ),
          metadata: metadata,
          finished_at: now
        )
      end
    end

    def validate_time!(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      raise Invalid.new(reason_code: "scan_usage_time_invalid")
    end
  end
end
