# frozen_string_literal: true

module Tenancy
  AuthorizationMembership = Data.define(:id, :organization_id, :user_id, :status, :owner) do
    def initialize(id:, organization_id:, user_id:, status:, owner:)
      super(id: id.to_s.freeze, organization_id: organization_id.to_s.freeze,
        user_id: user_id.to_s.freeze, status: status.to_s.freeze, owner: !!owner)
      freeze
    end

    def active?
      status == "active"
    end

    def owner?
      owner
    end
  end
end
