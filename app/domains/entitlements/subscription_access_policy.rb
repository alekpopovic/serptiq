# frozen_string_literal: true

module Entitlements
  class SubscriptionAccessPolicy
    REMEDIATION_PERMISSIONS = %w[billing.read billing.manage plans.read entitlements.read].freeze
    READ_PERMISSIONS = %w[
      scans.read findings.read issues.read integrations.read releases.read reports.read
      reports.export notifications.read api_keys.read webhooks.read audit_log.read audit_log.export
      data.export usage.read projects.read properties.read
    ].freeze
    STOP_PERMISSIONS = %w[scans.cancel].freeze
    SCHEDULE_PERMISSIONS = %w[scans.configure reports.schedule].freeze
    SCHEDULE_ENTITLEMENTS = %w[crawl.schedule reports.scheduled].freeze

    def call(organization_id:, permission_key:, entitlement_key: nil, at: Time.current)
      context = SubscriptionContext.active.find_by(organization_id: organization_id)
      return allowed(nil, nil, "not_applicable") unless context

      state = effective_state(context, at)
      action = action_class(permission_key.to_s, entitlement_key.to_s)
      permitted = permitted?(state, action)
      SubscriptionAccessDecision.new(
        allowed: permitted,
        reason_code: permitted ? "subscription_access_granted" : denial_reason(state),
        subscription_status: context.subscription_status,
        access_state: state,
        action_class: action
      )
    end

    private

    def effective_state(context, at)
      return "read_only" if context.subscription_status == "past_due" &&
        context.grace_ends_at && at >= context.grace_ends_at
      return "read_only" if context.subscription_status == "canceled" &&
        context.access_expires_at && at >= context.access_expires_at

      context.access_state
    end

    def action_class(permission, entitlement)
      return "remediation" if REMEDIATION_PERMISSIONS.include?(permission)
      return "read" if READ_PERMISSIONS.include?(permission) || STOP_PERMISSIONS.include?(permission)
      return "scheduled" if SCHEDULE_PERMISSIONS.include?(permission) ||
        SCHEDULE_ENTITLEMENTS.include?(entitlement)
      return "billable" if permission.in?(%w[scans.run reports.generate])
      return "integration" if permission == "integrations.manage"

      "write"
    end

    def permitted?(state, action)
      return true if action == "remediation"
      return true if state == "full"
      return true if action == "read" && state.in?(%w[grace read_only])
      return true if state == "grace" && action.in?(%w[billable integration write])

      false
    end

    def denial_reason(state)
      {
        "pending" => "subscription_incomplete",
        "read_only" => "subscription_read_only",
        "suspended" => "subscription_suspended"
      }.fetch(state, "subscription_action_paused")
    end

    def allowed(status, state, action)
      SubscriptionAccessDecision.new(
        allowed: true,
        reason_code: "subscription_access_not_applicable",
        subscription_status: status,
        access_state: state,
        action_class: action
      )
    end
  end
end
