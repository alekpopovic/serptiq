# frozen_string_literal: true

module Tenancy
  IssuedInvitation = Data.define(:invitation, :token) do
    def initialize(invitation:, token:)
      raise ArgumentError, "persisted invitation is required" unless invitation.is_a?(Invitation) && invitation.persisted?
      raise ArgumentError, "valid invitation token is required" unless InvitationToken.valid?(token)

      super(invitation: invitation, token: token.to_s.freeze)
      freeze
    end
  end
end
