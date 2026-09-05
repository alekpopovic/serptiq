# frozen_string_literal: true

module Crawling
  ScanDetail = Data.define(
    :summary, :initiator_type, :settings_digest, :entitlement_digest,
    :engine_version, :rule_set_version, :configuration_version,
    :release_id, :baseline_scan_id, :progress_sequence, :cost_breakdown, :events
  ) do
    def initialize(**attributes)
      attributes[:events] = attributes.fetch(:events).freeze
      super(**attributes)
      freeze
    end
  end
end
