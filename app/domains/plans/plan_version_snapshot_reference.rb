# frozen_string_literal: true

module Plans
  class PlanVersionSnapshotReference < ApplicationRecord
    self.table_name = "plan_version_snapshot_references"

    TYPES = %w[InvoiceSnapshot ReportSnapshot].freeze

    validates :plan_version_id, :reference_id, :created_at, presence: true
    validates :reference_type, inclusion: { in: TYPES }
    validates :reference_id, uniqueness: { scope: %i[reference_type plan_version_id] }

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "plan snapshot references are append-only"
    end
  end
end
