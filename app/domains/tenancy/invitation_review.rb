# frozen_string_literal: true

module Tenancy
  InvitationReview = Data.define(:id, :organization_id, :organization_name, :email, :expires_at, :initial_role_key) do
    def initialize(id:, organization_id:, organization_name:, email:, expires_at:, initial_role_key: nil)
      super
      freeze
    end
  end
end
