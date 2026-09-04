# frozen_string_literal: true

module Verification
  DnsResolution = Data.define(
    :status, :records, :record_count, :cname_hops, :delegation_count, :question_match
  ) do
    STATUSES = %w[
      resolved nxdomain no_record timeout transient_failure response_limit cname_limit
      delegation_limit malformed_response
    ].freeze

    def initialize(status:, records: [], record_count: 0, cname_hops: 0, delegation_count: 0,
      question_match: true)
      normalized_status = status.to_s
      raise ArgumentError, "invalid DNS resolution status" unless STATUSES.include?(normalized_status)

      values = Array(records).map { |record| record.to_s.b.freeze }.freeze
      values = [] unless normalized_status == "resolved"
      super(
        status: normalized_status.freeze,
        records: values,
        record_count: Integer(record_count).clamp(0, 1_000_000),
        cname_hops: Integer(cname_hops).clamp(0, 1_000_000),
        delegation_count: Integer(delegation_count).clamp(0, 1_000_000),
        question_match: !!question_match
      )
      freeze
    end

    def resolved?
      status == "resolved"
    end

    def evidence
      {
        record_count: record_count,
        cname_hops: cname_hops,
        delegation_count: delegation_count,
        question_match: question_match,
        multiple_records: record_count > 1
      }
    end
  end
end
