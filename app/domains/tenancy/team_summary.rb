# frozen_string_literal: true

module Tenancy
  TeamSummary = Data.define(:id, :name, :status, :archived_at, :member_count) do
    def initialize(id:, name:, status:, archived_at:, member_count:)
      super(
        id: id.to_s.freeze,
        name: name.to_s.freeze,
        status: status.to_s.freeze,
        archived_at: archived_at,
        member_count: Integer(member_count)
      )
      freeze
    end

    def active?
      status == "active"
    end
  end
end
