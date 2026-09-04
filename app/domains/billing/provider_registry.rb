# frozen_string_literal: true

module Billing
  class ProviderRegistry
    def initialize(environment: Rails.env.to_s, builders: nil)
      @environment = environment.to_s
      @builders = builders || { "fake" => -> { FakeProvider.new } }
    end

    def fetch(provider_key)
      key = provider_key.to_s
      builder = @builders[key]
      raise ProviderUnknown unless builder
      if key == "fake" && !%w[development test].include?(@environment)
        raise ProviderUnknown.new(reason_code: "billing_fake_provider_forbidden")
      end

      provider = builder.call
      raise ProviderUnknown unless provider.is_a?(Provider) && provider.provider_key == key

      provider
    end
  end
end
