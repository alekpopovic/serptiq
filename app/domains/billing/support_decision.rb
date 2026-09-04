# frozen_string_literal: true

module Billing
  SupportDecision = Data.define(:allowed, :permission_key, :actor_user_id, :reason_code) do
    def initialize(allowed:, permission_key:, actor_user_id:, reason_code:)
      super(
        allowed: !!allowed,
        permission_key: permission_key.to_s.freeze,
        actor_user_id: actor_user_id&.to_s&.freeze,
        reason_code: reason_code.to_s.freeze
      )
      freeze
    end

    def allow?
      allowed
    end
  end
end
