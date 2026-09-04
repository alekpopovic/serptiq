# frozen_string_literal: true

module Billing
  ReconciliationSummary = Data.define(
    :id, :organization_id, :subscription_id, :provider, :environment, :source, :state,
    :difference_fields, :failure_category, :requested_at, :completed_at, :next_attempt_at, :attempt_count
  ) do
    def initialize(**attributes)
      %i[id organization_id subscription_id provider environment source state failure_category].each do |name|
        attributes[name] = attributes.fetch(name)&.to_s&.freeze
      end
      attributes[:difference_fields] = Array(attributes.fetch(:difference_fields)).map { |value| value.to_s.freeze }.freeze
      super(**attributes)
      freeze
    end
  end
end
