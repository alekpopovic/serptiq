# frozen_string_literal: true

require "openssl"

module TestSupport
  module CryptoHelpers
    DEFAULT_SIGNATURE_HEADER = "X-SearchOps-Signature"
    DEFAULT_TIMESTAMP_HEADER = "X-SearchOps-Timestamp"

    def signed_request_headers(body:, secret:, timestamp: DeterministicHelpers::FIXED_TIME.to_i)
      payload = "#{timestamp}.#{body}"
      signature = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
      {
        DEFAULT_TIMESTAMP_HEADER => timestamp.to_s,
        DEFAULT_SIGNATURE_HEADER => "sha256=#{signature}"
      }.freeze
    end

    def assert_encrypted_value(plaintext:, ciphertext:)
      refute_nil ciphertext
      refute_equal plaintext.to_s, ciphertext.to_s
      refute_includes ciphertext.to_s, plaintext.to_s if plaintext.to_s.present?
    end

    def assert_encrypted_attribute(record:, attribute:, stored_value:)
      plaintext = record.public_send(attribute)
      assert_encrypted_value(plaintext: plaintext, ciphertext: stored_value)
      assert_equal plaintext, record.reload.public_send(attribute)
    end
  end
end
