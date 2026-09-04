# frozen_string_literal: true

module Tenancy
  AuthorizationTeam = Data.define(:id, :organization_id, :status, :member_ids) do
    def initialize(id:, organization_id:, status:, member_ids:)
      super(id: id.to_s.freeze, organization_id: organization_id.to_s.freeze,
        status: status.to_s.freeze, member_ids: member_ids.map { |value| value.to_s.freeze }.freeze)
      freeze
    end

    def active?
      status == "active"
    end

    def includes_membership?(membership_id)
      member_ids.include?(membership_id.to_s)
    end
  end
end
