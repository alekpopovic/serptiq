# frozen_string_literal: true

module Tenancy
  TeamDetails = Data.define(:team, :members, :candidates, :member_page, :next_member_page, :previous_member_page) do
    def initialize(team:, members:, candidates:, member_page:, next_member_page:, previous_member_page:)
      super(
        team: team,
        members: members.freeze,
        candidates: candidates.freeze,
        member_page: member_page,
        next_member_page: next_member_page,
        previous_member_page: previous_member_page
      )
      freeze
    end
  end
end
