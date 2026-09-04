# frozen_string_literal: true

module Auditing
  ConsistencyIssue = Data.define(:audit_event_id, :reason_code) do
    def initialize(audit_event_id:, reason_code:)
      super(audit_event_id: audit_event_id.to_s.freeze, reason_code: reason_code.to_s.freeze)
      freeze
    end
  end
end
