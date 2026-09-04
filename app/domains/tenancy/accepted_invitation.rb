# frozen_string_literal: true

module Tenancy
  AcceptedInvitation = Data.define(
    :membership, :initial_role_key, :initial_scope_type, :initial_scope_id, :invited_by_membership_id
  ) do
    def initialize(membership:, initial_role_key:, initial_scope_type:, initial_scope_id:,
      invited_by_membership_id:)
      super(
        membership: membership,
        initial_role_key: initial_role_key&.to_s&.freeze,
        initial_scope_type: initial_scope_type&.to_s&.freeze,
        initial_scope_id: initial_scope_id&.to_s&.freeze,
        invited_by_membership_id: invited_by_membership_id.to_s.freeze
      )
      freeze
    end

    def role_intent?
      initial_role_key.present?
    end
  end
end
