# frozen_string_literal: true

module Identity
  class ProviderAdapter
    attr_reader :configuration

    def initialize(configuration:)
      raise ArgumentError, "provider configuration is required" unless configuration.is_a?(ProviderConfiguration)

      @configuration = configuration
    end

    def provider
      configuration.provider
    end

    def authorization_request(**)
      raise NotImplementedError, "provider adapter must implement #authorization_request"
    end

    def exchange_callback(_input)
      raise NotImplementedError, "provider adapter must implement #exchange_callback"
    end
  end
end
