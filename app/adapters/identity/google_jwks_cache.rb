# frozen_string_literal: true

require "base64"
require "openssl"
require "thread"

module Identity
  class GoogleJwksCache
    Key = Data.define(:key_id, :algorithm, :public_key) do
      def inspect
        "#<#{self.class.name} key_id=#{key_id.inspect} algorithm=#{algorithm.inspect}>"
      end
    end

    KEY_ID_PATTERN = /\A[A-Za-z0-9._-]{1,128}\z/
    MODULUS_PATTERN = /\A[A-Za-z0-9_-]{342,683}\z/
    EXPONENT_PATTERN = /\A[A-Za-z0-9_-]{2,16}\z/
    ALGORITHM = "RS256"

    def initialize(fetcher:, ttl:, max_keys:, clock: -> { Time.current })
      @fetcher = fetcher
      @ttl = ttl
      @max_keys = max_keys
      @clock = clock
      @mutex = Mutex.new
      @keys = nil
      @expires_at = nil
      validate_limits!
    end

    def key_for(key_id, algorithm:)
      unless algorithm == ALGORITHM && KEY_ID_PATTERN.match?(key_id.to_s)
        raise malformed("google_jwks_key_metadata_invalid")
      end

      @mutex.synchronize do
        refresh_if_stale
        key = @keys[key_id]
        unless key
          refresh
          key = @keys[key_id]
        end
        raise malformed("google_jwks_key_not_found") unless key

        key
      end
    end

    private

    def refresh_if_stale
      return if @keys && @expires_at > @clock.call

      refresh
    end

    def refresh
      payload = @fetcher.call
      raw_keys = payload["keys"]
      unless raw_keys.is_a?(Array) && raw_keys.length.between?(1, @max_keys)
        raise malformed("google_jwks_payload_invalid")
      end

      parsed = raw_keys.to_h do |raw_key|
        key = parse_key(raw_key)
        [ key.key_id, key ]
      end
      if parsed.length != raw_keys.length
        raise malformed("google_jwks_duplicate_key_id")
      end

      @keys = parsed.freeze
      @expires_at = @clock.call + @ttl
    end

    def parse_key(raw_key)
      unless raw_key.is_a?(Hash) && raw_key["kty"] == "RSA" && raw_key["alg"] == ALGORITHM &&
          [ nil, "sig" ].include?(raw_key["use"])
        raise malformed("google_jwks_key_invalid")
      end

      key_id = raw_key["kid"]
      modulus = raw_key["n"]
      exponent = raw_key["e"]
      unless KEY_ID_PATTERN.match?(key_id.to_s) && MODULUS_PATTERN.match?(modulus.to_s) &&
          EXPONENT_PATTERN.match?(exponent.to_s)
        raise malformed("google_jwks_key_invalid")
      end

      public_key = build_rsa_key(decode_integer(modulus), decode_integer(exponent))
      unless public_key.n.num_bits.between?(2048, 4096) && public_key.e.odd? && public_key.e >= 3
        raise malformed("google_jwks_key_invalid")
      end

      Key.new(key_id.freeze, ALGORITHM, public_key)
    rescue ArgumentError, OpenSSL::OpenSSLError
      raise malformed("google_jwks_key_invalid"), cause: nil
    end

    def decode_integer(value)
      decoded = Base64.urlsafe_decode64(padded(value))
      canonical = Base64.urlsafe_encode64(decoded, padding: false)
      raise ArgumentError, "noncanonical JWK integer" unless canonical == value

      OpenSSL::BN.new(decoded, 2)
    end

    def padded(value)
      value + ("=" * ((4 - (value.length % 4)) % 4))
    end

    def build_rsa_key(modulus, exponent)
      rsa = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Integer(modulus),
        OpenSSL::ASN1::Integer(exponent)
      ])
      algorithm = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::ObjectId("rsaEncryption"),
        OpenSSL::ASN1::Null(nil)
      ])
      OpenSSL::PKey.read(OpenSSL::ASN1::Sequence([
        algorithm,
        OpenSSL::ASN1::BitString(rsa.to_der)
      ]).to_der)
    end

    def validate_limits!
      valid = @ttl.is_a?(Numeric) && @ttl.between?(60, 21_600) &&
        @max_keys.is_a?(Integer) && @max_keys.between?(1, 32)
      raise ArgumentError, "JWKS cache limits are invalid" unless valid
    end

    def malformed(reason_code)
      ProviderError.new(category: "malformed_response", operation: "jwks", reason_code: reason_code)
    end
  end
end
