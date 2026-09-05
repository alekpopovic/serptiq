# frozen_string_literal: true

module Crawling
  SCAN_COUNTER_ATTRIBUTES = %i[
    targets_count urls_discovered_count urls_queued_count urls_running_count
    urls_processed_count urls_succeeded_count urls_failed_count urls_skipped_count
    findings_count
  ].freeze

  ScanCounters = Data.define(*SCAN_COUNTER_ATTRIBUTES) do
    def initialize(**attributes)
      normalized = SCAN_COUNTER_ATTRIBUTES.to_h do |name|
        value = Integer(attributes.fetch(name, 0))
        raise ArgumentError, "scan counter is negative" if value.negative?

        [ name, value ]
      end
      processed_parts = normalized.values_at(
        :urls_succeeded_count, :urls_failed_count, :urls_skipped_count
      ).sum
      raise ArgumentError, "processed URL counter is inconsistent" unless
        normalized[:urls_processed_count] == processed_parts
      raise ArgumentError, "discovered URL counter is inconsistent" unless
        normalized[:urls_discovered_count] >= normalized[:urls_processed_count] +
          normalized[:urls_queued_count] + normalized[:urls_running_count]

      super(**normalized)
      freeze
    end

    def to_h
      SCAN_COUNTER_ATTRIBUTES.to_h { |name| [ name, public_send(name) ] }.freeze
    end

    def monotonic_from?(other)
      monotonic = SCAN_COUNTER_ATTRIBUTES - %i[urls_queued_count urls_running_count]
      monotonic.all? { |name| public_send(name) >= other.public_send(name) }
    end
  end
end
