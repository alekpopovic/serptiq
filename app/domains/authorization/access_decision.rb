# frozen_string_literal: true

module Authorization
  AccessDecision = Data.define(
    :allowed, :stage, :reason_code, :public_error_code, :authorization,
    :entitlement, :reservation, :quota_denial, :provenance
  ) do
    def initialize(allowed:, stage:, reason_code:, public_error_code: nil, authorization:,
      entitlement: nil, reservation: nil, quota_denial: nil, provenance: {})
      super(
        allowed: !!allowed,
        stage: stage.to_s.freeze,
        reason_code: reason_code.to_s.freeze,
        public_error_code: public_error_code&.to_s&.freeze,
        authorization: authorization,
        entitlement: entitlement,
        reservation: reservation,
        quota_denial: quota_denial,
        provenance: provenance.to_h.transform_values { |value| immutable(value) }.freeze
      )
      freeze
    end

    def allow?
      allowed
    end

    def deny?
      !allowed
    end

    def reserved?
      reservation.present?
    end

    private

    def immutable(value)
      case value
      when Array then value.map { |item| immutable(item) }.freeze
      when Hash then value.transform_values { |item| immutable(item) }.freeze
      when String then value.dup.freeze
      else value
      end
    end
  end
end
