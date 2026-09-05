# frozen_string_literal: true

module Crawling
  class SchedulePendingDispatches
    BATCH_SIZE = 100

    def initialize(enqueuer: EnqueueScanDispatch.new)
      @enqueuer = enqueuer
    end

    def call
      pending_ids.each do |organization_id, scan_id|
        @enqueuer.call(organization_id: organization_id, scan_id: scan_id)
      end
    end

    private

    def pending_ids
      Scan.where(status: "admitted", dispatch_enqueued_at: nil)
        .order(:admitted_at, :id)
        .limit(BATCH_SIZE)
        .pluck(:organization_id, :id)
    end
  end
end
