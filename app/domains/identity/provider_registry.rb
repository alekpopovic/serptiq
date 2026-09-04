# frozen_string_literal: true

module Identity
  class ProviderRegistry
    def self.from_settings(settings: Rails.application.config.x.searchops)
      configurations = ProviderIdentity::PROVIDERS.filter_map do |provider|
        next unless settings.fetch("oauth_#{provider}_enabled".to_sym)

        ProviderConfiguration.from_settings(provider: provider, settings: settings)
      end
      adapters = configurations.to_h { |configuration| [ configuration.provider, yield(configuration) ] }
      new(configurations: configurations, adapters: adapters)
    end

    def initialize(configurations:, adapters:)
      @configurations = configurations.index_by(&:provider).freeze
      @adapters = adapters.transform_keys(&:to_s).freeze
      validate!
      freeze
    end

    def fetch(provider)
      provider = provider.to_s
      unless ProviderIdentity::PROVIDERS.include?(provider)
        raise ProviderError.new(
          category: "configuration",
          operation: "provider_lookup",
          reason_code: "provider_unknown"
        )
      end
      @adapters.fetch(provider) do
        raise ProviderError.new(
          category: "configuration",
          operation: "provider_lookup",
          reason_code: "provider_unconfigured"
        )
      end
    end

    def configured_providers
      @adapters.keys.sort.freeze
    end

    private

    def validate!
      unknown = (@configurations.keys | @adapters.keys) - ProviderIdentity::PROVIDERS
      raise ArgumentError, "registry contains an unknown provider" if unknown.any?
      raise ArgumentError, "registry adapter/configuration mismatch" unless @configurations.keys.sort == @adapters.keys.sort

      @adapters.each do |provider, adapter|
        valid = adapter.respond_to?(:provider) && adapter.provider.to_s == provider &&
          adapter.respond_to?(:configuration) && adapter.configuration.equal?(@configurations.fetch(provider)) &&
          adapter.respond_to?(:authorization_request) && adapter.respond_to?(:exchange_callback)
        raise ArgumentError, "provider adapter does not satisfy the contract" unless valid
      end
    end
  end
end
