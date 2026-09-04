# frozen_string_literal: true

module Verification
  class SearchConsoleCatalog
    def initialize(client:, access: Access.new, integration_permission: IntegrationPermission.new,
      token: SearchConsoleSelectionToken.new)
      @client = client
      @access = access
      @integration_permission = integration_permission
      @token = token
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:)
      context = @access.call(
        actor_membership: actor_membership,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id,
        permission_key: "properties.verify"
      )
      @integration_permission.call(
        actor_membership: actor_membership,
        organization_id: context.environment.organization_id
      )
      connections = Integrations::Public.search_console_connections(
        organization_id: context.environment.organization_id
      )
      return SearchConsoleCatalogResult.new(status: "no_connection") if connections.empty?

      options = []
      saw_match = false
      saw_insufficient = false
      connections.each do |connection|
        accesses = list_properties(connection)
        grouped = accesses.group_by(&:external_property_identifier)
        return SearchConsoleCatalogResult.new(status: "ambiguous") if grouped.any? { |_key, rows| rows.many? }

        grouped.each_value do |rows|
          access = rows.sole
          identifier = SearchConsolePropertyIdentifier.parse(access.external_property_identifier)
          next unless identifier.matches_origin?(context.environment.origin.origin)

          saw_match = true
          unless access.owner?
            saw_insufficient = true
            next
          end
          options << SearchConsoleOption.new(
            selection_token: @token.issue(
              connection_id: connection.id,
              external_property_identifier: identifier.external_identifier
            ),
            external_property_identifier: identifier.external_identifier,
            property_type: identifier.property_type,
            permission_level: access.permission_level
          )
        end
      end
      return SearchConsoleCatalogResult.new(status: "ambiguous") if
        options.map(&:external_property_identifier).tally.any? { |_identifier, count| count > 1 }
      return SearchConsoleCatalogResult.new(status: "available", options: options) if options.any?
      return SearchConsoleCatalogResult.new(status: "insufficient_permission") if saw_match && saw_insufficient

      SearchConsoleCatalogResult.new(status: "no_match")
    rescue Integrations::Public::SearchConsoleClientError, SearchConsoleSelectionError, ArgumentError
      SearchConsoleCatalogResult.new(status: "provider_unavailable")
    end

    private

    def list_properties(connection)
      value = @client.list_properties(connection: connection)
      raise ArgumentError, "Search Console property list is invalid" unless
        value.is_a?(Array) && value.length <= SearchConsoleSelectionResolver::MAX_PROPERTIES &&
          value.all? { |item| item.is_a?(Integrations::Public::SearchConsolePropertyAccess) }

      value
    end
  end
end
