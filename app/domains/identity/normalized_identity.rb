# frozen_string_literal: true

require "json"
require "uri"

module Identity
  class NormalizedIdentity
    attr_reader :provider, :subject, :email, :email_verified, :profile

    def initialize(provider:, subject:, email:, email_verified:, profile: {})
      @provider = provider.to_s.downcase.freeze
      @subject = subject.to_s.dup.freeze
      @email = email.to_s.strip.downcase.presence&.freeze
      @email_verified = email_verified
      @profile = profile.to_h.to_h do |key, value|
        [ key.to_s.freeze, value.is_a?(String) ? value.dup.freeze : value ]
      end.freeze
      validate!
      freeze
    end

    def email_verified?
      email_verified == true
    end

    def inspect
      "#<#{self.class.name} provider=#{provider.inspect} subject=[FILTERED] email=[FILTERED] " \
        "email_verified=#{email_verified?} profile_keys=#{profile.keys.sort.inspect}>"
    end

    private

    def validate!
      raise ArgumentError, "unsupported identity provider" unless ProviderIdentity::PROVIDERS.include?(provider)
      unless ProviderIdentity::SUBJECT_PATTERN.match?(subject) && subject.bytesize <= 255
        raise ArgumentError, "provider subject is invalid"
      end
      raise ArgumentError, "email verification must be boolean" unless [ true, false ].include?(email_verified)
      raise ArgumentError, "verified email must be present" if email_verified? && email.nil?
      raise ArgumentError, "email is invalid" if email && !URI::MailTo::EMAIL_REGEXP.match?(email)

      validate_profile!
    end

    def validate_profile!
      unknown_keys = profile.keys - ProviderIdentity::PROFILE_KEYS
      valid_values = profile.values.all? do |value|
        value.nil? || (value.is_a?(String) && value.bytesize <= 2048)
      end
      valid_size = JSON.generate(profile).bytesize <= 8192
      raise ArgumentError, "normalized profile is invalid" if unknown_keys.any? || !valid_values || !valid_size
    rescue JSON::GeneratorError
      raise ArgumentError, "normalized profile is invalid"
    end
  end
end
