# frozen_string_literal: true

module Crawling
  class FrontierProgressQuery
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, scan_id:)
      scan = Scan.select(:id, :status, *ScanCounters.members)
        .find_by!(organization_id: organization_id, id: scan_id)
      FrontierProgressSnapshot.new(
        scan_id: scan.id,
        status: scan.status,
        **ScanCounters.members.to_h { |name| [ name, scan.public_send(name) ] },
        observed_at: @clock.call
      )
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "frontier_scope_unavailable"), cause: nil
    end
  end
end
