# frozen_string_literal: true

module Crawling
  ScanDetail = Data.define(
    :summary, :initiator_type, :settings_digest, :entitlement_digest,
    :engine_version, :rule_set_version, :configuration_version,
    :release_id, :baseline_scan_id, :progress_sequence, :cost_breakdown, :events,
    :fetch_observation_count, :page_snapshot_count
  ) do
    def initialize(**attributes)
      attributes[:events] = attributes.fetch(:events).freeze
      attributes[:fetch_observation_count] = Integer(attributes.fetch(:fetch_observation_count, 0))
      attributes[:page_snapshot_count] = Integer(attributes.fetch(:page_snapshot_count, 0))
      super(**attributes)
      freeze
    end
  end
end
