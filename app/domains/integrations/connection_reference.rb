# frozen_string_literal: true

module Integrations
  ConnectionReference = Data.define(
    :id, :organization_id, :provider, :external_account_id, :granted_scopes,
    :state, :credential_revision, :consented_at
  ) do
    def initialize(**attributes)
      %i[id organization_id provider external_account_id state].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      attributes[:granted_scopes] = Array(attributes.fetch(:granted_scopes)).map(&:to_s).freeze
      attributes[:credential_revision] = Integer(attributes.fetch(:credential_revision))
      super(**attributes)
      freeze
    end

    def usable?
      state.in?(%w[connected healthy degraded]) &&
        granted_scopes.include?(SearchConsole::READONLY_SCOPE)
    end
  end
end
