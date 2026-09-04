# frozen_string_literal: true

require "uri"

module Identity
  class AuthorizationRequest
    attr_reader :provider, :uri

    def initialize(provider:, uri:)
      @provider = provider.to_s.dup.freeze
      @uri = uri.is_a?(URI::Generic) ? uri.dup : URI.parse(uri.to_s)
      validate!
      @uri.freeze
      freeze
    rescue URI::InvalidURIError
      raise ArgumentError, "authorization URI is invalid"
    end

    def to_s
      uri.to_s
    end

    def inspect
      "#<#{self.class.name} provider=#{provider.inspect} uri=[FILTERED_URL]>"
    end

    private

    def validate!
      raise ArgumentError, "unsupported provider" unless ProviderIdentity::PROVIDERS.include?(provider)
      valid = uri.scheme == "https" && uri.host.present? && uri.userinfo.nil? && uri.fragment.nil?
      raise ArgumentError, "authorization URI must be an HTTPS URL without credentials or fragment" unless valid
    end
  end
end
