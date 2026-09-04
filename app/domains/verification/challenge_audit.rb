# frozen_string_literal: true

module Verification
  module ChallengeAudit
    module_function

    def record!(action:, challenge:, actor_membership_id:, operation:, failure_category: nil)
      Auditing::Public.record!(
        organization_id: challenge.organization_id,
        actor_membership_id: actor_membership_id,
        action: action,
        target_type: "DomainVerification",
        target_id: challenge.id,
        result: action.end_with?("failed") ? "failed" : "succeeded",
        metadata: {
          operation: operation,
          method: challenge.method,
          status: challenge.state,
          failure_category: failure_category,
          attempt_count: challenge.attempt_count
        }
      )
    end
  end
end
