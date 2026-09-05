# frozen_string_literal: true

module Crawling
  PressureLimits = Data.define(
    :global_concurrency, :organization_concurrency, :scan_concurrency, :host_concurrency,
    :global_rate, :organization_rate, :scan_rate, :host_rate,
    :permit_duration, :scan_deadline
  ) do
    def initialize(**attributes)
      %i[global_concurrency organization_concurrency scan_concurrency host_concurrency].each do |name|
        attributes[name] = Integer(attributes.fetch(name))
      end
      %i[global_rate organization_rate scan_rate host_rate permit_duration].each do |name|
        attributes[name] = Float(attributes.fetch(name))
      end
      valid = attributes.values_at(
        :global_concurrency, :organization_concurrency, :scan_concurrency, :host_concurrency
      ).all? { |value| value.between?(1, 1_000_000) } &&
        attributes.values_at(:global_rate, :organization_rate, :scan_rate, :host_rate)
          .all? { |value| value.finite? && value.between?(0.1, 100_000) } &&
        attributes[:permit_duration].between?(1, 900) && attributes.fetch(:scan_deadline).respond_to?(:utc)
      raise ArgumentError, "crawl pressure limits are invalid" unless valid

      super(**attributes)
      freeze
    end

    def effective_concurrency
      [ global_concurrency, organization_concurrency, scan_concurrency, host_concurrency ].min
    end

    def effective_rate
      [ global_rate, organization_rate, scan_rate, host_rate ].min
    end
  end
end
