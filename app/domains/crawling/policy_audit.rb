# frozen_string_literal: true

module Crawling
  module PolicyAudit
    module_function

    def record!(action:, actor_membership_id:, policy_set:, operation:, changed_fields: [])
      Auditing::Public.record!(
        organization_id: policy_set.organization_id,
        actor_membership_id: actor_membership_id,
        action: action,
        target_type: "CrawlPolicy",
        target_id: policy_set.id,
        result: "succeeded",
        metadata: {
          operation: operation,
          changed_fields: Array(changed_fields).map(&:to_s).sort
        }
      )
    end
  end
end
