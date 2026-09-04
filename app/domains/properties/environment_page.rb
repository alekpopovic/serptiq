# frozen_string_literal: true

module Properties
  EnvironmentPage = Data.define(:entries, :page, :per_page, :total_count, :query) do
    def initialize(entries:, page:, per_page:, total_count:, query:)
      super(
        entries: entries.freeze,
        page: Integer(page),
        per_page: Integer(per_page),
        total_count: Integer(total_count),
        query: query.to_s.freeze
      )
      freeze
    end

    def total_pages
      [ (total_count.to_f / per_page).ceil, 1 ].max
    end
  end
end
