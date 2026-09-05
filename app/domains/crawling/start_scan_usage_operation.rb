# frozen_string_literal: true

module Crawling
  class StartScanUsageOperation
    def initialize(clock: -> { Time.current }, identity: ScanUsageIdentity.new,
      meter_resolver: ResolveScanMeterContext.new)
      @clock = clock
      @identity = identity
      @meter_resolver = meter_resolver
    end

    def call(organization_id:, scan_id:, source_key:, operation_kind:, at: @clock.call, metadata: {})
      now = validate_time!(at)
      kind = operation_kind.to_s
      raise Invalid.new(reason_code: "scan_usage_operation_invalid") unless
        ScanUsageOperation::KINDS.include?(kind)
      digest = @identity.digest(source_key)
      normalized_metadata = @identity.metadata(metadata)
      checksum = @identity.checksum(
        organization_id: organization_id.to_s,
        scan_id: scan_id.to_s,
        source_key_digest: digest,
        operation_kind: kind,
        metadata: normalized_metadata
      )
      replay = operation_replay(organization_id, scan_id, digest, checksum)
      return replay if replay

      ScanUsageOperation.transaction do
        scan = Scan.lock.find_by!(id: scan_id, organization_id: organization_id)
        replay = operation_replay(organization_id, scan_id, digest, checksum)
        next replay if replay
        raise Conflict.new(reason_code: "scan_usage_operation_unavailable") unless scan.status == "running"

        context = kind == "artifact" ? nil : @meter_resolver.call(scan: scan, operation_kind: kind)
        allocation = allocate(scan, context, digest, now)
        ScanUsageOperation.create!(
          organization_id: scan.organization_id,
          project_id: scan.project_id,
          property_id: scan.property_id,
          environment_id: scan.environment_id,
          scan_id: scan.id,
          usage_quota_allocation_id: allocation&.id,
          operation_kind: kind,
          meter_key: context&.key,
          meter_rate_version: context&.rate&.version,
          applied_weight: context&.rate&.weight,
          reserved_credits: allocation&.billed_quantity || 0,
          source_key_digest: digest,
          request_checksum: checksum,
          state: "reserved",
          metadata: normalized_metadata,
          attempted_at: now
        )
      end
    rescue Usage::Public::QuotaExceeded => error
      pause_for_quota(organization_id, scan_id, error, now)
      raise
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_scope_unavailable"), cause: nil
    rescue ActiveRecord::RecordNotUnique
      operation_replay(organization_id, scan_id, digest, checksum) || raise
    end

    private

    def allocate(scan, context, digest, now)
      return unless context

      Usage::Public.allocate_reservation(
        clock: -> { now },
        organization_id: scan.organization_id,
        reservation_id: scan.usage_quota_reservation_id,
        idempotency_key: "scan-usage-allocation:#{scan.id}:#{digest}",
        window: context.window,
        meter_rate: context.rate,
        quantity: 1,
        at: now
      )
    end

    def operation_replay(organization_id, scan_id, digest, checksum)
      operation = ScanUsageOperation.find_by(
        organization_id: organization_id,
        scan_id: scan_id,
        source_key_digest: digest
      )
      return unless operation
      return operation if operation.request_checksum == checksum

      raise Conflict.new(reason_code: "scan_usage_idempotency_conflict")
    end

    def pause_for_quota(organization_id, scan_id, error, at)
      Scan.transaction do
        scan = Scan.lock.find_by(id: scan_id, organization_id: organization_id)
        next unless scan && !scan.terminal?

        scan.update!(
          throttled_at: at,
          throttle_reason: "quota_exhausted",
          throttle_until: error.denial.reset_at
        )
      end
    end

    def validate_time!(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      raise Invalid.new(reason_code: "scan_usage_time_invalid")
    end
  end
end
