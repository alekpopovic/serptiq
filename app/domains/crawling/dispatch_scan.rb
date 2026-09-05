# frozen_string_literal: true

module Crawling
  class DispatchScan
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, scan_id:)
      scan = Scan.find_by(organization_id: organization_id, id: scan_id)
      return unless scan
      return scan unless scan.status == "admitted"

      reservation = Usage::Public.reservation_reference(
        organization_id: scan.organization_id,
        reservation_id: scan.usage_quota_reservation_id
      )
      unless reservation&.active_at?(@clock.call)
        return TransitionScan.new(clock: @clock).call(
          organization_id: scan.organization_id,
          scan_id: scan.id,
          command: "fail",
          failure_category: "quota_reservation_unavailable"
        )
      end

      TransitionScan.new(clock: @clock).call(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        command: "queue"
      )
    end
  end
end
