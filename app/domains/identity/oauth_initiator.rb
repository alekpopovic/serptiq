# frozen_string_literal: true

require "ipaddr"
require "openssl"

module Identity
  class OauthInitiator
    KEY_PURPOSE = "identity/oauth-initiator/v1"
    UNAVAILABLE_ADDRESS = "unavailable"

    attr_reader :digest

    def self.from_request(request, key: nil)
      address = IPAddr.new(request.remote_ip).to_s
      new(address: address, key: key)
    rescue ActionDispatch::RemoteIp::IpSpoofAttackError, IPAddr::InvalidAddressError
      new(address: UNAVAILABLE_ADDRESS, key: key)
    end

    def initialize(address:, key: nil)
      secret = key || Rails.application.key_generator.generate_key(KEY_PURPOSE, 32)
      @digest = OpenSSL::HMAC.hexdigest("SHA256", secret, address.to_s).freeze
      freeze
    end

    def inspect
      "#<#{self.class.name} digest=#{digest.inspect}>"
    end
  end
end
