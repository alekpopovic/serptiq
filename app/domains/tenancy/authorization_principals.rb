# frozen_string_literal: true

module Tenancy
  AuthorizationPrincipals = Data.define(:membership_id, :team_ids) do
    def initialize(membership_id:, team_ids:)
      super(membership_id: membership_id&.to_s&.freeze, team_ids: team_ids.map { |id| id.to_s.freeze }.freeze)
      freeze
    end

    def active?
      membership_id.present?
    end
  end
end
