# frozen_string_literal: true

module Crawling
  PressureMetricsSnapshot = Data.define(
    :active_permits, :stale_permits, :throttled_scans, :backed_off_hosts,
    :disabled_hosts, :global_disabled, :maximum_wait_seconds, :alerting
  ) do
    def initialize(**attributes)
      %i[
        active_permits stale_permits throttled_scans backed_off_hosts disabled_hosts maximum_wait_seconds
      ].each { |name| attributes[name] = Integer(attributes.fetch(name)) }
      super(**attributes)
      freeze
    end
  end
end
