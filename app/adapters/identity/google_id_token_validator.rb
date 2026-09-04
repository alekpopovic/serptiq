# frozen_string_literal: true

require "base64"
require "json"
require "openssl"

module Identity
  class GoogleIdTokenValidator
    class StrictJsonObject < Hash
      def []=(key, value)
        raise JSON::ParserError, "duplicate JSON object member" if key?(key)

        super
      end
    end

    MAX_TOKEN_BYTES = 16_384
    MAX_SEGMENT_BYTES = 12_000
    SEGMENT_PATTERN = /\A[A-Za-z0-9_-]+\z/
    ALGORITHM = "RS256"

    def initialize(configuration:, jwks_cache:, clock_skew:, max_token_lifetime:, clock: -> { Time.current })
      @configuration = configuration
      @jwks_cache = jwks_cache
      @clock_skew = clock_skew
      @max_token_lifetime = max_token_lifetime
      @clock = clock
      validate_configuration!
    end

    def call(token:, callback_input:)
      raise malformed("google_id_token_oversized") unless token.to_s.bytesize.between?(32, MAX_TOKEN_BYTES)
      raise malformed("google_callback_context_invalid") unless callback_input.is_a?(CallbackInput)

      segments = token.split(".", -1)
      unless segments.length == 3 && segments.all?(&:present?)
        raise malformed("google_id_token_format_invalid")
      end
      encoded_header, encoded_payload, encoded_signature = segments

      header = parse_object(encoded_header, reason_code: "google_id_token_header_invalid")
      payload = parse_object(encoded_payload, reason_code: "google_id_token_payload_invalid")
      algorithm, key_id = validate_header(header)
      key = @jwks_cache.key_for(key_id, algorithm: algorithm)
      signature = decode_segment(encoded_signature)
      valid_signature = key.public_key.verify(
        OpenSSL::Digest::SHA256.new,
        signature,
        "#{encoded_header}.#{encoded_payload}"
      )
      raise malformed("google_id_token_signature_invalid") unless valid_signature

      [ validate_claims(payload, callback_input: callback_input, key: key), payload.freeze ].freeze
    rescue ProviderError
      raise
    rescue ArgumentError, EncodingError, JSON::ParserError, JSON::NestingError, OpenSSL::OpenSSLError
      raise malformed("google_id_token_malformed"), cause: nil
    end

    private

    def validate_header(header)
      algorithm = header["alg"]
      key_id = header["kid"]
      unsafe_key_reference = %w[jku jwk x5u crit].any? { |name| header.key?(name) }
      valid_type = !header.key?("typ") || header["typ"] == "JWT"
      unless algorithm == ALGORITHM && GoogleJwksCache::KEY_ID_PATTERN.match?(key_id.to_s) &&
          !unsafe_key_reference && valid_type
        raise malformed("google_id_token_header_rejected")
      end

      [ algorithm, key_id ]
    end

    def validate_claims(payload, callback_input:, key:)
      issuer = required_string(payload, "iss", maximum: 255)
      subject = required_string(payload, "sub", maximum: 255)
      audiences = audiences(payload["aud"])
      authorized_party = optional_string(payload, "azp", maximum: 255)
      issued_at = numeric_time(payload, "iat")
      expires_at = numeric_time(payload, "exp")
      not_before = payload.key?("nbf") ? numeric_time(payload, "nbf") : nil
      nonce = required_string(payload, "nonce", maximum: 1024)

      raise malformed("google_id_token_issuer_invalid") unless issuer == @configuration.issuer.to_s
      raise malformed("google_id_token_subject_invalid") unless ProviderIdentity::SUBJECT_PATTERN.match?(subject)
      raise malformed("google_id_token_audience_invalid") unless audiences.include?(@configuration.client_id)
      if audiences.length > 1 && authorized_party.nil?
        raise malformed("google_id_token_authorized_party_missing")
      end
      if authorized_party && authorized_party != @configuration.client_id
        raise malformed("google_id_token_authorized_party_invalid")
      end

      validate_times!(issued_at, expires_at, not_before, callback_input.issued_after)
      raise malformed("google_id_token_nonce_invalid") unless callback_input.nonce_matches?(nonce)

      OidcClaims.new(
        issuer: issuer,
        subject: subject,
        audiences: audiences,
        authorized_party: authorized_party,
        issued_at: issued_at,
        expires_at: expires_at,
        not_before: not_before,
        nonce: nonce,
        key_id: key.key_id,
        algorithm: key.algorithm
      )
    end

    def validate_times!(issued_at, expires_at, not_before, issued_after)
      now = @clock.call
      raise malformed("google_id_token_issue_context_missing") unless issued_after&.respond_to?(:to_time)
      raise malformed("google_id_token_expired") unless expires_at > now - @clock_skew
      raise malformed("google_id_token_not_yet_valid") if not_before && not_before > now + @clock_skew
      unless issued_at <= now + @clock_skew && issued_at >= issued_after.to_time - @clock_skew
        raise malformed("google_id_token_issued_at_invalid")
      end
      unless expires_at > issued_at && expires_at <= issued_at + @max_token_lifetime
        raise malformed("google_id_token_lifetime_invalid")
      end
    end

    def audiences(value)
      values = value.is_a?(String) ? [ value ] : value
      valid = values.is_a?(Array) && values.length.between?(1, 8) &&
        values.uniq.length == values.length &&
        values.all? { |audience| audience.is_a?(String) && audience.bytesize.between?(1, 255) }
      raise malformed("google_id_token_audience_invalid") unless valid

      values.uniq.freeze
    end

    def numeric_time(payload, key)
      value = payload[key]
      valid = value.is_a?(Numeric) && value.finite? && value.between?(0, (2**53) - 1)
      raise malformed("google_id_token_time_invalid") unless valid

      Time.at(value).utc
    rescue RangeError
      raise malformed("google_id_token_time_invalid"), cause: nil
    end

    def required_string(payload, key, maximum:)
      value = payload[key]
      unless value.is_a?(String) && value.bytesize.between?(1, maximum)
        raise malformed("google_id_token_claim_invalid")
      end

      value
    end

    def optional_string(payload, key, maximum:)
      return unless payload.key?(key)

      required_string(payload, key, maximum: maximum)
    end

    def parse_object(segment, reason_code:)
      decoded = decode_segment(segment)
      decoded.force_encoding(Encoding::UTF_8)
      raise malformed(reason_code) unless decoded.valid_encoding?

      object = JSON.parse(decoded, max_nesting: 16, object_class: StrictJsonObject)
      raise malformed(reason_code) unless object.is_a?(Hash)

      object
    end

    def decode_segment(segment)
      unless segment.bytesize.between?(1, MAX_SEGMENT_BYTES) && SEGMENT_PATTERN.match?(segment)
        raise ArgumentError, "invalid JWT segment"
      end

      decoded = Base64.urlsafe_decode64(segment + ("=" * ((4 - (segment.length % 4)) % 4)))
      canonical = Base64.urlsafe_encode64(decoded, padding: false)
      raise ArgumentError, "noncanonical JWT segment" unless canonical == segment

      decoded
    end

    def validate_configuration!
      valid = @configuration.is_a?(ProviderConfiguration) && @configuration.provider == "google" &&
        @clock_skew.is_a?(Numeric) && @clock_skew.between?(0, 300) &&
        @max_token_lifetime.is_a?(Numeric) && @max_token_lifetime.between?(300, 7200)
      raise ArgumentError, "Google ID token validation configuration is invalid" unless valid
    end

    def malformed(reason_code)
      ProviderError.new(category: "malformed_response", operation: "id_token_validation", reason_code: reason_code)
    end
  end
end
