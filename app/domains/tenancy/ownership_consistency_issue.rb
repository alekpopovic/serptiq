# frozen_string_literal: true

module Tenancy
  OwnershipConsistencyIssue = Data.define(:organization_id, :reason_code) do
    def initialize(organization_id:, reason_code:)
      super(
        organization_id: organization_id.to_s.freeze,
        reason_code: reason_code.to_s.freeze
      )
      freeze
    end
  end
end
