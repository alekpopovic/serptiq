# frozen_string_literal: true

module Crawling
  ScanEventSummary = Data.define(:sequence, :event_type, :from_status, :to_status, :occurred_at) do
    def initialize(sequence:, event_type:, from_status:, to_status:, occurred_at:)
      super(
        sequence: Integer(sequence),
        event_type: event_type.to_s.freeze,
        from_status: from_status&.to_s&.freeze,
        to_status: to_status.to_s.freeze,
        occurred_at: occurred_at
      )
      freeze
    end
  end
end
