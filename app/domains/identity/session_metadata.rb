# frozen_string_literal: true

require "openssl"

module Identity
  class SessionMetadata
    KEY_PURPOSE = "identity/session-metadata/v1"

    attr_reader :ip_address_digest, :user_agent_digest

    def self.from_request(request)
      new(ip_address: request.remote_ip, user_agent: request.user_agent)
    rescue ActionDispatch::RemoteIp::IpSpoofAttackError
      new(ip_address: nil, user_agent: request.user_agent)
    end

    def self.empty
      new(ip_address: nil, user_agent: nil)
    end

    def initialize(ip_address:, user_agent:, key: nil)
      @key = key || Rails.application.key_generator.generate_key(KEY_PURPOSE, 32)
      @ip_address_digest = digest(ip_address)
      @user_agent_digest = digest(user_agent)
      freeze
    end

    def inspect
      "#<#{self.class.name} ip_address_digest=#{ip_address_digest.inspect} " \
        "user_agent_digest=#{user_agent_digest.inspect}>"
    end

    private

    def digest(value)
      normalized = value.to_s.strip
      return if normalized.empty?

      OpenSSL::HMAC.hexdigest("SHA256", @key, normalized.byteslice(0, 2048))
    end
  end
end
