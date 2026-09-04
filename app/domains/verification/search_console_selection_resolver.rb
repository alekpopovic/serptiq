# frozen_string_literal: true

module Verification
  class SearchConsoleSelectionResolver
    MAX_PROPERTIES = 500

    def initialize(client:, clock: -> { Time.current })
      raise ArgumentError, "Search Console client must list properties" unless client.respond_to?(:list_properties)

      @client = client
      @clock = clock
    end

    def call(organization_id:, connection_id:, external_property_identifier:, origin:,
      expected_connection_revision: nil)
      connection = Integrations::Public.search_console_connection(
        organization_id: organization_id,
        connection_id: connection_id
      )
      raise SearchConsoleSelectionError, "provider_scope_revoked" unless connection&.usable?
      if expected_connection_revision && connection.credential_revision != expected_connection_revision
        raise SearchConsoleSelectionError, "provider_connection_changed"
      end

      accesses = normalized_accesses(@client.list_properties(connection: connection))
      candidates = accesses.select do |access|
        access.external_property_identifier == external_property_identifier.to_s
      end
      raise SearchConsoleSelectionError, "provider_property_inaccessible" if candidates.empty?
      raise SearchConsoleSelectionError, "provider_ambiguous_match" if candidates.many?

      access = candidates.sole
      identifier = SearchConsolePropertyIdentifier.parse(access.external_property_identifier)
      raise SearchConsoleSelectionError, "provider_no_match" unless identifier.matches_origin?(origin)

      observation = ProviderObservation.new(
        external_property_identifier: identifier.external_identifier,
        permission_level: access.permission_level,
        checked_at: @clock.call
      )
      raise SearchConsoleSelectionError.new(
        "provider_insufficient_permission", observation: observation
      ) unless access.owner?

      SearchConsoleSelection.new(
        connection_id: connection.id,
        external_property_identifier: identifier.external_identifier,
        property_type: identifier.property_type,
        permission_level: access.permission_level,
        checked_at: observation.checked_at,
        connection_revision: connection.credential_revision
      )
    rescue Integrations::Public::SearchConsoleClientError => error
      category = {
        "revoked_scope" => "provider_scope_revoked",
        "inaccessible_property" => "provider_property_inaccessible",
        "outage" => "provider_outage",
        "malformed_response" => "malformed_response"
      }.fetch(error.reason_code)
      raise SearchConsoleSelectionError, category
    rescue SearchConsoleSelectionError
      raise
    rescue ArgumentError, TypeError
      raise SearchConsoleSelectionError, "malformed_response"
    end

    private

    def normalized_accesses(value)
      raise ArgumentError, "Search Console property list is invalid" unless
        value.is_a?(Array) && value.length <= MAX_PROPERTIES &&
          value.all? { |item| item.is_a?(Integrations::Public::SearchConsolePropertyAccess) }

      value
    end
  end
end
