# frozen_string_literal: true

module Tenancy
  InvitationSummary = Data.define(:organization_name, :expires_at) do
    def initialize(organization_name:, expires_at:)
      super
      freeze
    end
  end
end
