# frozen_string_literal: true

module Integrations
  module Public
    SearchConsoleClientError = SearchConsole::ClientError
    SearchConsolePropertyAccess = SearchConsole::PropertyAccess
    SEARCH_CONSOLE_PERMISSION_LEVELS = SearchConsole::PROPERTY_PERMISSION_LEVELS

    module_function

    # Connections currently belong to the organization rather than a project.
    # The ordered deletion stage is still explicit so a later project-scoped
    # credential cannot ship without extending this boundary.
    def prepare_resource_deletion(organization_id:, project_id:, property_id: nil)
      project = Projects::Public.reference(organization_id: organization_id, project_id: project_id)
      return 0 if project

      raise AccessDenied
    end

    def register_search_console_connection(**attributes)
      RegisterSearchConsoleConnection.new.call(**attributes)
    end

    def search_console_connections(organization_id:)
      ConnectionDirectory.new.available_for_verification(organization_id: organization_id)
    end

    def search_console_connection(organization_id:, connection_id:)
      ConnectionDirectory.new.find_for_verification(
        organization_id: organization_id,
        connection_id: connection_id
      )
    end

    def unconfigured_search_console_client
      SearchConsole::UnconfiguredClient.new
    end
  end
end
