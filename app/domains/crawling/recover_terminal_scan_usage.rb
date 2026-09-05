# frozen_string_literal: true

module Crawling
  class RecoverTerminalScanUsage
    BATCH_SIZE = 100

    def initialize(finalizer: FinalizeScanUsage.new)
      @finalizer = finalizer
    end

    def call(batch_size: BATCH_SIZE)
      limit = Integer(batch_size).clamp(1, BATCH_SIZE)
      targets = Scan.terminal.left_joins(:quota_reservation, :usage_operations)
        .where("usage_quota_reservations.state = 'held' OR crawl_scan_usage_operations.state = 'reserved'")
        .select("scans.organization_id, scans.id, scans.updated_at")
        .distinct.order("scans.updated_at", "scans.id").limit(limit)
        .map { |scan| [ scan.organization_id, scan.id ] }
      targets.count do |organization_id, scan_id|
        @finalizer.call(organization_id: organization_id, scan_id: scan_id)
        true
      rescue Conflict, AccessDenied, Usage::Public::Conflict
        false
      end
    end
  end
end
