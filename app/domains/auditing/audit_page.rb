# frozen_string_literal: true

module Auditing
  AuditPage = Data.define(:records, :number, :page_size, :total_count) do
    def initialize(records:, number:, page_size:, total_count:)
      super(records: records.freeze, number: number, page_size: page_size, total_count: total_count)
      freeze
    end

    def previous_page
      number > 1 ? number - 1 : nil
    end

    def next_page
      number * page_size < total_count ? number + 1 : nil
    end
  end
end
