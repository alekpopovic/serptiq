# frozen_string_literal: true

require "openssl"

module Identity
  class SessionMetadata
    KEY_PURPOSE = "identity/session-metadata/v1"

    CLIENT_NAMES = [ "Chrome", "Edge", "Firefox", "Safari", "Other client", "Unknown client" ].freeze
    DEVICE_TYPES = [ "Desktop", "Mobile", "Tablet", "Unknown" ].freeze

    attr_reader :ip_address_digest, :user_agent_digest, :client_name, :device_type

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
      @client_name = classify_client(user_agent)
      @device_type = classify_device(user_agent)
      freeze
    end

    def inspect
      "#<#{self.class.name} ip_address_digest=#{ip_address_digest.inspect} " \
        "user_agent_digest=#{user_agent_digest.inspect} client_name=#{client_name.inspect} " \
        "device_type=#{device_type.inspect}>"
    end

    private

    def digest(value)
      normalized = value.to_s.strip
      return if normalized.empty?

      OpenSSL::HMAC.hexdigest("SHA256", @key, normalized.byteslice(0, 2048))
    end

    def classify_client(user_agent)
      value = user_agent.to_s.byteslice(0, 2048)
      return "Unknown client" if value.blank?
      return "Edge" if value.match?(/\b(?:Edg|EdgiOS|EdgA)\//)
      return "Firefox" if value.match?(/\b(?:Firefox|FxiOS)\//)
      return "Chrome" if value.match?(/\b(?:Chrome|CriOS)\//)
      return "Safari" if value.include?("Safari/")

      "Other client"
    end

    def classify_device(user_agent)
      value = user_agent.to_s.byteslice(0, 2048)
      return "Unknown" if value.blank?
      return "Tablet" if value.match?(/\b(?:iPad|Tablet)\b/i)
      return "Mobile" if value.match?(/\b(?:Mobile|Android|iPhone)\b/i)

      "Desktop"
    end
  end
end
