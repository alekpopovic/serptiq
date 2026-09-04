# frozen_string_literal: true

module Tenancy
  OwnershipTransferResult = Data.define(
    :organization, :previous_ownership, :current_ownership, :previous_owner,
    :current_owner, :issued_session, :revoked_current_owner_sessions
  ) do
    def initialize(organization:, previous_ownership:, current_ownership:, previous_owner:,
      current_owner:, issued_session:, revoked_current_owner_sessions:)
      super
      freeze
    end
  end
end
