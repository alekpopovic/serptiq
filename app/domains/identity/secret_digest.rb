# frozen_string_literal: true

require "openssl"

module Identity
  module SecretDigest
    PURPOSE_PATTERN = /\A[a-z][a-z0-9_-]{0,63}\z/

    module_function

    def call(value, purpose:)
      material = value.to_s
      validate_material!(material)
      validate_purpose!(purpose)

      OpenSSL::HMAC.hexdigest("SHA256", key(purpose), material)
    end

    def matches?(value, digest, purpose:)
      candidate = call(value, purpose: purpose)
      digest.to_s.bytesize == candidate.bytesize && ActiveSupport::SecurityUtils.secure_compare(candidate, digest.to_s)
    rescue ArgumentError
      false
    end

    def key(purpose)
      Rails.application.key_generator.generate_key("identity/#{purpose}/digest/v1", 32)
    end
    private_class_method :key

    def validate_material!(material)
      raise ArgumentError, "secret material must be present and bounded" unless material.bytesize.between?(32, 1024)
    end
    private_class_method :validate_material!

    def validate_purpose!(purpose)
      raise ArgumentError, "invalid digest purpose" unless PURPOSE_PATTERN.match?(purpose.to_s)
    end
    private_class_method :validate_purpose!
  end
end
