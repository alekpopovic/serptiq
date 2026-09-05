# frozen_string_literal: true

module Crawling
  ScanSummary = Data.define(
    :id, :project_id, :property_id, :environment_id, :scan_type, :status,
    :requested_at, :started_at, :finished_at, :failure_category,
    :throttled_at, :throttle_reason, :throttle_until, :counters
  ) do
    def initialize(**attributes)
      %i[id project_id property_id environment_id scan_type status].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end

    def terminal?
      status.in?(Scan::TERMINAL_STATUSES)
    end

    def cancellable?
      status.in?(%w[requested admitted queued running])
    end

    def throttled?
      throttled_at.present?
    end
  end
end
