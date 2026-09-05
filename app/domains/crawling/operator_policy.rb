# frozen_string_literal: true

module Crawling
  class OperatorPolicy
    def authorize!(user:)
      user_id = user.id.to_s if user&.respond_to?(:id)
      allowed = user&.respond_to?(:active?) && user.active? &&
        ControlAccessGrant.active.exists?(user_id: user_id, permission: ControlAccessGrant::PERMISSION)
      raise OperatorAccessDenied unless allowed

      user
    end
  end
end
