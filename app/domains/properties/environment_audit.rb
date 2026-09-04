# frozen_string_literal: true

module Properties
  module EnvironmentAudit
    module_function

    def record!(action:, actor_membership_id:, environment:, operation:, changed_fields: [])
      Auditing::Public.record!(
        organization_id: environment.organization_id,
        actor_membership_id: actor_membership_id,
        action: action,
        target_type: "PropertyEnvironment",
        target_id: environment.id,
        result: "succeeded",
        metadata: {
          operation: operation,
          event_kind: environment.kind,
          changed_fields: Array(changed_fields).map(&:to_s).sort
        }
      )
    end
  end
end
