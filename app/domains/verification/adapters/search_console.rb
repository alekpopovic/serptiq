# frozen_string_literal: true

module Verification
  module Adapters
    class SearchConsole
      attr_reader :method

      def initialize(client:, resolver: nil)
        @resolver = resolver || SearchConsoleSelectionResolver.new(client: client)
        @method = "search_console"
      end

      def verify(challenge:, expected_value:)
        return AdapterResult.new(verified: false, failure_category: "malformed_response") unless
          ChallengeToken.valid_for?(challenge, expected_value)

        selection = @resolver.call(
          organization_id: challenge.organization_id,
          connection_id: challenge.integration_connection_id,
          external_property_identifier: challenge.provider_property_identifier,
          origin: challenge.bound_origin,
          expected_connection_revision: challenge.connection_revision
        )
        AdapterResult.new(
          verified: true,
          evidence: {
            provider_property_match: true,
            provider_permission_owner: true,
            connection_revision_match: true
          },
          provider_observation: selection.provider_observation
        )
      rescue SearchConsoleSelectionError => error
        AdapterResult.new(
          verified: false,
          failure_category: error.failure_category,
          evidence: {
            provider_property_match: error.failure_category == "provider_insufficient_permission",
            provider_permission_owner: false,
            connection_revision_match: error.failure_category != "provider_connection_changed"
          },
          provider_observation: error.observation
        )
      rescue StandardError
        AdapterResult.new(verified: false, failure_category: "provider_outage")
      end
    end
  end
end
