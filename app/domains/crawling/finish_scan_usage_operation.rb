# frozen_string_literal: true

module Crawling
  class FinishScanUsageOperation
    def initialize(clock: -> { Time.current }, identity: ScanUsageIdentity.new)
      @clock = clock
      @identity = identity
    end

    def call(organization_id:, scan_id:, source_key:, outcome:, occurred_at: @clock.call,
      at: @clock.call, metadata: {})
      now = validate_time!(at)
      occurred = validate_time!(occurred_at)
      result = outcome.to_s
      raise Invalid.new(reason_code: "scan_usage_outcome_invalid") unless
        result.in?(ScanUsageOperation::OUTCOMES - [ "abandoned" ])
      digest = @identity.digest(source_key)
      finish_metadata = @identity.metadata(metadata)
      operation = find_operation!(organization_id, scan_id, digest)
      checksum = completion_checksum(operation, result, occurred, finish_metadata)
      return verify_replay!(operation, checksum) unless operation.reserved?

      ScanUsageOperation.transaction do
        scan = Scan.lock.find_by!(id: scan_id, organization_id: organization_id)
        locked = ScanUsageOperation.lock.find_by!(
          id: operation.id, organization_id: organization_id, scan_id: scan_id
        )
        next verify_replay!(locked, checksum) unless locked.reserved?
        raise Conflict.new(reason_code: "scan_usage_operation_unavailable") if scan.terminal?

        metadata = locked.metadata.merge(finish_metadata)
        if billable?(locked, result)
          allocation = Usage::Public.consume_allocation(
            clock: -> { now },
            organization_id: organization_id,
            allocation_id: locked.usage_quota_allocation_id,
            idempotency_key: "scan-usage-consume:#{locked.source_key_digest}",
            occurred_at: occurred,
            at: now,
            metadata: usage_metadata(locked, metadata)
          )
          locked.update!(
            state: "billed",
            outcome: result,
            completion_checksum: checksum,
            usage_event_id: allocation.usage_event_id,
            metadata: metadata,
            finished_at: now
          )
        else
          release_allocation(locked, result, occurred, now, metadata)
          locked.update!(
            state: "not_billable",
            outcome: result,
            completion_checksum: checksum,
            metadata: metadata,
            finished_at: now
          )
        end
        locked
      end
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_scope_unavailable"), cause: nil
    end

    private

    def find_operation!(organization_id, scan_id, digest)
      ScanUsageOperation.find_by!(
        organization_id: organization_id,
        scan_id: scan_id,
        source_key_digest: digest
      )
    end

    def billable?(operation, outcome)
      operation.operation_kind != "artifact" && outcome == "accepted"
    end

    def release_allocation(operation, outcome, occurred, now, metadata)
      return unless operation.usage_quota_allocation_id

      Usage::Public.release_allocation(
        clock: -> { now },
        organization_id: operation.organization_id,
        allocation_id: operation.usage_quota_allocation_id,
        idempotency_key: "scan-usage-release:#{operation.source_key_digest}",
        occurred_at: occurred,
        at: now,
        metadata: usage_metadata(operation, metadata).merge("outcome" => outcome)
      )
    end

    def usage_metadata(operation, _metadata)
      {
        "scan_id" => operation.scan_id,
        "operation" => operation.operation_kind,
        "source_digest" => operation.source_key_digest
      }
    end

    def completion_checksum(operation, outcome, occurred, metadata)
      @identity.checksum(
        operation_id: operation.id,
        outcome: outcome,
        occurred_at: occurred,
        metadata: metadata
      )
    end

    def verify_replay!(operation, expected_checksum)
      return operation if operation.completion_checksum == expected_checksum

      raise Conflict.new(reason_code: "scan_usage_idempotency_conflict")
    end

    def validate_time!(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      raise Invalid.new(reason_code: "scan_usage_time_invalid")
    end
  end
end
