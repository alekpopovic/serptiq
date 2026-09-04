# frozen_string_literal: true

module Integrations
  module SearchConsole
    class UnconfiguredClient
      def list_properties(connection:)
        connection
        raise ClientError, "outage"
      end
    end
  end
end
