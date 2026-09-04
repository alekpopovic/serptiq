# frozen_string_literal: true

module Usage
  ReservationReconciliationResult = Data.define(:expired_count, :checked_count, :inconsistency_count) do
    def consistent?
      inconsistency_count.zero?
    end
  end
end
