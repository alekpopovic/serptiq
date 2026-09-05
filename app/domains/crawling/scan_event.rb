# frozen_string_literal: true

module Crawling
  class ScanEvent < ApplicationRecord
    self.table_name = "scan_events"

    EVENT_TYPES = %w[
      scan.requested scan.admitted scan.queued scan.started scan.cancel_requested
      scan.canceled scan.completed scan.partially_completed scan.failed
      scan.progress_recorded
    ].freeze

    belongs_to :scan, class_name: "Crawling::Scan", inverse_of: :events

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :occurred_at, :created_at, presence: true
    validates :sequence, numericality: { only_integer: true, greater_than: 0 },
      uniqueness: { scope: :scan_id }
    validates :event_type, inclusion: { in: EVENT_TYPES }
    validates :from_status, inclusion: { in: Scan::STATUSES }, allow_nil: true
    validates :to_status, inclusion: { in: Scan::STATUSES }
    validates :idempotency_key_digest, uniqueness: { scope: :scan_id },
      format: { with: /\A[0-9a-f]{64}\z/ }
    validates :payload_digest, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :failure_category, format: { with: Scan::FAILURE_CATEGORY_PATTERN }, allow_nil: true
    validate :counter_consistency

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "scan events are append-only"
    end

    def counters
      ScanCounters.new(**SCAN_COUNTER_ATTRIBUTES.to_h { |name| [ name, public_send(name) ] })
    end

    private

    def counter_consistency
      counters
    rescue ArgumentError => error
      errors.add(:base, error.message)
    end
  end
end
