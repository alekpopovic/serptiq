# frozen_string_literal: true

require "json"
require "openssl"

module Billing
  class CheckoutCorrelation
    PURPOSE = "searchops.billing.checkout.v1"

    def initialize(secret: Rails.application.secret_key_base)
      @secret = ValueNormalization.string!(secret, name: "correlation secret", maximum: 4096)
    end

    def sign(organization_id:, plan_version_id:, checkout_session_id:, environment:)
      OpenSSL::HMAC.hexdigest("SHA256", @secret, canonical_payload(
        organization_id: organization_id,
        plan_version_id: plan_version_id,
        checkout_session_id: checkout_session_id,
        environment: environment
      )).freeze
    end

    def valid?(signature:, **attributes)
      candidate = signature.to_s
      return false unless candidate.match?(/\A[0-9a-f]{64}\z/)

      ActiveSupport::SecurityUtils.secure_compare(candidate, sign(**attributes))
    end

    private

    def canonical_payload(organization_id:, plan_version_id:, checkout_session_id:, environment:)
      JSON.generate([
        PURPOSE,
        ValueNormalization.uuid!(organization_id, name: "organization"),
        ValueNormalization.uuid!(plan_version_id, name: "plan version"),
        ValueNormalization.uuid!(checkout_session_id, name: "checkout session"),
        ValueNormalization.string!(environment, name: "environment", maximum: 16)
      ])
    end
  end
end
