# frozen_string_literal: true

module Identity
  class OidcClaims
    attr_reader :issuer, :subject, :audiences, :authorized_party, :issued_at, :expires_at,
      :not_before, :nonce, :key_id, :algorithm

    def initialize(issuer:, subject:, audiences:, authorized_party:, issued_at:, expires_at:,
      nonce:, key_id:, algorithm:, not_before: nil)
      @issuer = issuer.to_s.dup.freeze
      @subject = subject.to_s.dup.freeze
      @audiences = Array(audiences).map { |audience| audience.to_s.dup.freeze }.uniq.freeze
      @authorized_party = authorized_party&.to_s&.dup&.freeze
      @issued_at = issued_at
      @expires_at = expires_at
      @not_before = not_before
      @nonce = nonce.to_s.dup.freeze
      @key_id = key_id.to_s.dup.freeze
      @algorithm = algorithm.to_s.dup.freeze
      validate!
      freeze
    end

    def inspect
      "#<#{self.class.name} issuer=#{issuer.inspect} subject=[FILTERED] " \
        "audiences=#{audiences.inspect} authorized_party=#{authorized_party.inspect} " \
        "issued_at=#{issued_at.inspect} expires_at=#{expires_at.inspect} not_before=#{not_before.inspect} " \
        "nonce=[FILTERED] key_id=#{key_id.inspect} algorithm=#{algorithm.inspect}>"
    end

    private

    def validate!
      raise ArgumentError, "OIDC issuer is required" if issuer.blank?
      unless ProviderIdentity::SUBJECT_PATTERN.match?(subject) && subject.bytesize <= 255
        raise ArgumentError, "OIDC subject is invalid"
      end
      raise ArgumentError, "OIDC audience is required" if audiences.empty?
      raise ArgumentError, "OIDC timestamps are required" unless issued_at.respond_to?(:to_time) && expires_at.respond_to?(:to_time)
      raise ArgumentError, "OIDC nonce is required" if nonce.blank?
      raise ArgumentError, "OIDC key metadata is required" if key_id.blank? || algorithm.blank?
    end
  end
end
