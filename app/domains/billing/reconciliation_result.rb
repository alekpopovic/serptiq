# frozen_string_literal: true

module Billing
  ReconciliationResult = Data.define(
    :provider, :started_at, :finished_at, :checked, :updated, :unchanged,
    :failed, :failure_categories
  ) do
    def initialize(provider:, started_at:, finished_at:, checked:, updated:, unchanged:,
      failed:, failure_categories: [])
      started = ValueNormalization.time!(started_at, name: "reconciliation start")
      finished = ValueNormalization.time!(finished_at, name: "reconciliation finish")
      raise ArgumentError, "reconciliation finish must follow start" if finished < started
      counts = [ checked, updated, unchanged, failed ]
      unless counts.all? { |count| count.is_a?(Integer) && count >= 0 } &&
          updated + unchanged + failed == checked
        raise ArgumentError, "reconciliation counts are invalid"
      end
      categories = Array(failure_categories).map do |category|
        ValueNormalization.string!(
          category, name: "failure category", maximum: 64, pattern: ValueNormalization::KEY_PATTERN
        )
      end.uniq.sort.freeze

      super(
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        started_at: started,
        finished_at: finished,
        checked: checked,
        updated: updated,
        unchanged: unchanged,
        failed: failed,
        failure_categories: categories
      )
      freeze
    end

    def success?
      failed.zero?
    end

    def as_json(*)
      to_h.freeze
    end
  end
end
