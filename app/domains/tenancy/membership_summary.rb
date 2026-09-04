# frozen_string_literal: true

module Tenancy
  MembershipSummary = Data.define(
    :id, :display_name, :status, :accepted_at, :suspended_at, :removed_at, :owner
  ) do
    def initialize(id:, display_name:, status:, accepted_at:, suspended_at:, removed_at:, owner:)
      super(
        id: id.to_s.freeze,
        display_name: display_name.to_s.freeze,
        status: status.to_s.freeze,
        accepted_at: accepted_at,
        suspended_at: suspended_at,
        removed_at: removed_at,
        owner: owner == true
      )
      freeze
    end

    def owner?
      owner
    end
  end
end
