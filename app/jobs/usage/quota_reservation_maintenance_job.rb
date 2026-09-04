# frozen_string_literal: true

module Usage
  class QuotaReservationMaintenanceJob < ApplicationJob
    runs_on :maintenance
    system_authorization :quota_reservation_maintenance,
      reason: "expires abandoned quota holds and reconciles finalized usage events"

    def perform
      MaintainQuotaReservations.new.call
    end
  end
end
