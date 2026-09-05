# frozen_string_literal: true

module Crawling
  class LocalArtifactToken
    PURPOSE = "private-artifact-download-v1"
    MAX_TTL = 15.minutes

    def initialize(secret: Rails.application.secret_key_base, clock: -> { Time.current })
      key = ActiveSupport::KeyGenerator.new(secret).generate_key(PURPOSE, 32)
      @encryptor = ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
      @clock = clock
    end

    def issue(key:, artifact_id:, expires_in:)
      ttl = Float(expires_in)
      raise ArgumentError, "artifact URL lifetime is invalid" unless ttl.between?(1, MAX_TTL.to_f)

      @encryptor.encrypt_and_sign(
        { "key" => key.to_s, "artifact_id" => artifact_id.to_s,
          "expires_at" => (@clock.call + ttl).to_i }, purpose: PURPOSE
      )
    end

    def read(token)
      payload = @encryptor.decrypt_and_verify(token.to_s, purpose: PURPOSE)
      valid = payload.is_a?(Hash) && ArtifactKey.valid?(payload["key"]) &&
        Shared::Public.application_uuid?(payload["artifact_id"]) && payload["expires_at"].to_i > @clock.call.to_i
      raise ActiveSupport::MessageEncryptor::InvalidMessage unless valid

      payload.freeze
    end
  end
end
