# frozen_string_literal: true

require "uri"

module Identity
  class CallbackInput
    CODE_PATTERN = /\A[^\s]{16,2048}\z/

    attr_reader :code, :redirect_uri, :pkce_verifier, :nonce

    def initialize(code:, redirect_uri:, pkce_verifier:, nonce: nil)
      @code = code.to_s.dup.freeze
      @redirect_uri = redirect_uri.is_a?(URI::Generic) ? redirect_uri.dup : URI.parse(redirect_uri.to_s)
      @pkce_verifier = pkce_verifier.to_s.dup.freeze
      @nonce = nonce&.to_s&.dup&.freeze
      validate!
      @redirect_uri.freeze
      freeze
    rescue URI::InvalidURIError
      raise ArgumentError, "callback redirect URI is invalid"
    end

    def inspect
      "#<#{self.class.name} code=[FILTERED] redirect_uri=#{redirect_uri.inspect} " \
        "pkce_verifier=[FILTERED] nonce=#{nonce ? '[FILTERED]' : 'nil'}>"
    end

    private

    def validate!
      raise ArgumentError, "authorization code must be present and bounded" unless CODE_PATTERN.match?(code)
      unless OauthTransaction::PKCE_VERIFIER_PATTERN.match?(pkce_verifier)
        raise ArgumentError, "PKCE verifier is invalid"
      end
      valid_scheme = redirect_uri.scheme == "https" || (redirect_uri.scheme == "http" && loopback_host?)
      valid_redirect = valid_scheme && redirect_uri.host.present? && redirect_uri.userinfo.nil? &&
        redirect_uri.query.nil? && redirect_uri.fragment.nil?
      raise ArgumentError, "callback redirect URI must be HTTPS or an HTTP loopback URL" unless valid_redirect
    end

    def loopback_host?
      [ "localhost", "127.0.0.1", "::1" ].include?(redirect_uri.host.to_s.downcase)
    end
  end
end
