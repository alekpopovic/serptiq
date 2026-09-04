# frozen_string_literal: true

require "uri"

module Identity
  class CallbackInput
    CODE_PATTERN = /\A[^\s]{16,2048}\z/

    attr_reader :code, :redirect_uri, :pkce_verifier, :nonce, :nonce_digest, :issued_after

    def initialize(code:, redirect_uri:, pkce_verifier:, nonce: nil, nonce_digest: nil, issued_after: nil)
      @code = code.to_s.dup.freeze
      @redirect_uri = redirect_uri.is_a?(URI::Generic) ? redirect_uri.dup : URI.parse(redirect_uri.to_s)
      @pkce_verifier = pkce_verifier.to_s.dup.freeze
      @nonce = nonce&.to_s&.dup&.freeze
      @nonce_digest = nonce_digest&.to_s&.dup&.freeze
      @issued_after = issued_after
      validate!
      @redirect_uri.freeze
      freeze
    rescue URI::InvalidURIError
      raise ArgumentError, "callback redirect URI is invalid"
    end

    def inspect
      "#<#{self.class.name} code=[FILTERED] redirect_uri=#{redirect_uri.inspect} " \
        "pkce_verifier=[FILTERED] nonce=#{nonce || nonce_digest ? '[FILTERED]' : 'nil'} " \
        "issued_after=#{issued_after.inspect}>"
    end

    def nonce_matches?(candidate)
      if nonce
        candidate.to_s.bytesize == nonce.bytesize && ActiveSupport::SecurityUtils.secure_compare(candidate.to_s, nonce)
      elsif nonce_digest
        SecretDigest.matches?(candidate, nonce_digest, purpose: "oauth-nonce")
      else
        false
      end
    end

    private

    def validate!
      raise ArgumentError, "authorization code must be present and bounded" unless CODE_PATTERN.match?(code)
      unless OauthTransaction::PKCE_VERIFIER_PATTERN.match?(pkce_verifier)
        raise ArgumentError, "PKCE verifier is invalid"
      end
      if nonce && nonce_digest
        raise ArgumentError, "callback nonce must use one protected representation"
      end
      if nonce_digest && !OauthTransaction::DIGEST_PATTERN.match?(nonce_digest)
        raise ArgumentError, "callback nonce digest is invalid"
      end
      if issued_after && !issued_after.respond_to?(:to_time)
        raise ArgumentError, "callback issue-time boundary is invalid"
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
