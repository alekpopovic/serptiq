# frozen_string_literal: true

module Tenancy
  MembershipPage = Data.define(:entries, :page, :per_page, :total_count) do
    def initialize(entries:, page:, per_page:, total_count:)
      super(entries: entries.freeze, page: page, per_page: per_page, total_count: total_count)
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
