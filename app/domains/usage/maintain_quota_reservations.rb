# frozen_string_literal: true

module Usage
  class MaintainQuotaReservations
    def initialize(expirer: ExpireQuotaReservations.new, reconciler: ReconcileQuotaReservations.new)
      @expirer = expirer
      @reconciler = reconciler
    end

    def call(at: Time.current)
      expired = @expirer.call(at: at)
      checked, inconsistent = @reconciler.call
      ReservationReconciliationResult.new(
        expired_count: expired,
        checked_count: checked,
        inconsistency_count: inconsistent
      )
    end
  end
end
