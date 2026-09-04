# frozen_string_literal: true

module Integrations
  class ConnectionDirectory
    def available_for_verification(organization_id:)
      Connection.available_for_verification.where(
        organization_id: organization_id,
        provider: "search_console"
      ).order(:created_at).map(&:reference).freeze
    end

    def find_for_verification(organization_id:, connection_id:)
      Connection.find_by(
        id: connection_id,
        organization_id: organization_id,
        provider: "search_console"
      )&.reference
    end
  end
end
