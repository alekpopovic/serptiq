# frozen_string_literal: true

module Billing
  class SupportDashboardQuery
    def call(authorization:, manage_decision:, event_state: nil)
      unless authorization.is_a?(SupportDecision) && authorization.allow? &&
          authorization.permission_key == "billing_support.read"
        raise SupportAccessDenied.new(reason_code: "billing_support_permission_missing")
      end

      SupportDashboard.new(
        events: WebhookEventInventory.new.call(state: event_state, limit: 50),
        reconciliations: ReconciliationRun.recent_first.limit(50).map(&:summary).freeze,
        mappings: MappingDiagnostics.new.call,
        consistency_issues: ConsistencyReport.new.call,
        metrics: OperationalMetrics.new.call(emit: true),
        manage_allowed: manage_decision.is_a?(SupportDecision) && manage_decision.allow?
      ).freeze
    end
  end
end
