# frozen_string_literal: true

module Crawling
  ScanMeterCost = Data.define(
    :operation_kind, :meter_key, :attempt_count, :accepted_count, :billable_count,
    :non_billable_count, :pending_count, :gross_credits, :net_credits
  ) do
    def initialize(**attributes)
      attributes[:operation_kind] = attributes.fetch(:operation_kind).to_s.dup.freeze
      attributes[:meter_key] = attributes[:meter_key]&.to_s&.dup&.freeze
      super(**attributes)
      freeze
    end
  end
end
