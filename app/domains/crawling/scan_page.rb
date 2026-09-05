# frozen_string_literal: true

module Crawling
  ScanPage = Data.define(:entries, :page, :per_page, :total_count) do
    def initialize(entries:, page:, per_page:, total_count:)
      super(
        entries: entries.freeze,
        page: Integer(page),
        per_page: Integer(per_page),
        total_count: Integer(total_count)
      )
      freeze
    end

    def previous_page
      page - 1 if page > 1
    end

    def next_page
      page + 1 if page * per_page < total_count
    end
  end
end
