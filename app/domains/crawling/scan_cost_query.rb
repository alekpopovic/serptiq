# frozen_string_literal: true

module Crawling
  class ScanCostQuery
    ZERO = BigDecimal("0").freeze

    def initialize(access: ScanAccess.new)
      @access = access
    end

    def call(actor_membership:, project_id:, scan_id:)
      context = @access.call(
        actor_membership: actor_membership,
        project_id: project_id,
        permission_key: "scans.read"
      )
      scan = Scan.includes(:quota_reservation).find_by!(
        id: scan_id,
        organization_id: context.project.organization_id,
        project_id: context.project.id
      )
      build(scan)
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_scope_unavailable"), cause: nil
    end

    def build(scan)
      operations = scan.usage_operations.order(:operation_kind, :id).to_a
      net_by_meter = Usage::Public.source_summary(
        organization_id: scan.organization_id,
        source_type: "Scan",
        source_id: scan.id
      )
      entries = ScanUsageOperation::KINDS.map do |kind|
        rows = operations.select { |operation| operation.operation_kind == kind }
        meter_key = rows.filter_map(&:meter_key).first || meter_key_from_snapshot(scan, kind)
        gross = rows.select(&:billed?).sum(ZERO, &:reserved_credits)
        ScanMeterCost.new(
          operation_kind: kind,
          meter_key: meter_key,
          attempt_count: rows.length,
          accepted_count: rows.count { |operation| operation.outcome == "accepted" },
          billable_count: rows.count(&:billed?),
          non_billable_count: rows.count(&:not_billable?),
          pending_count: rows.count(&:reserved?),
          gross_credits: gross,
          net_credits: meter_key ? net_by_meter.fetch(meter_key, ZERO) : ZERO
        )
      end
      reservation = scan.quota_reservation
      ScanCostBreakdown.new(
        scan_id: scan.id,
        estimated_credits: scan.credit_estimate || ZERO,
        gross_credits: entries.sum(ZERO, &:gross_credits),
        net_credits: entries.sum(ZERO, &:net_credits),
        reserved_credits: reservation&.held? ? reservation.held_quantity - reservation.consumed_quantity : ZERO,
        released_credits: reservation&.released_quantity || ZERO,
        entries: entries
      )
    end

    private

    def meter_key_from_snapshot(scan, kind)
      ResolveScanMeterContext::METER_KEYS[kind]
    end
  end
end
