# frozen_string_literal: true

module Entitlements
  SubscriptionAccessDecision = Data.define(
    :allowed, :reason_code, :subscription_status, :access_state, :action_class
  ) do
    def initialize(allowed:, reason_code:, subscription_status:, access_state:, action_class:)
      super(
        allowed: !!allowed,
        reason_code: reason_code.to_s.freeze,
        subscription_status: subscription_status&.to_s&.freeze,
        access_state: access_state&.to_s&.freeze,
        action_class: action_class.to_s.freeze
      )
      freeze
    end

    def allow?
      allowed
    end

    def deny?
      !allowed
    end
  end
end
