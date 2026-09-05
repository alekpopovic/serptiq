# frozen_string_literal: true

module Auditing
  class TargetTombstone < ApplicationRecord
    self.table_name = "audit_target_tombstones"

    TARGET_TYPES = %w[
      Project Property PropertyEnvironment DomainVerification CrawlPolicy Scan
    ].freeze

    validates :organization_id, :deletion_workflow_id, :target_id, :project_id,
      :deleted_at, :created_at, presence: true
    validates :target_type, inclusion: { in: TARGET_TYPES }

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "audit target tombstones are append-only"
    end
  end
end
