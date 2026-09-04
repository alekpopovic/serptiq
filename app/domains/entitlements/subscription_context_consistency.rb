# frozen_string_literal: true

module Entitlements
  class SubscriptionContextConsistency
    ISSUE_TYPES = %w[
      subscription_context_missing subscription_revision_mismatch subscription_projection_mismatch
    ].freeze

    def call
      rows = SubscriptionContext.connection.select_all(<<~SQL.squish)
        SELECT issue_type, COUNT(*)::integer AS issue_count
        FROM (
          SELECT 'subscription_context_missing' AS issue_type
          FROM subscriptions subscriptions
          LEFT JOIN entitlement_subscription_contexts contexts
            ON contexts.organization_id = subscriptions.organization_id
            AND contexts.subscription_id = subscriptions.id
            AND contexts.active = TRUE
          WHERE subscriptions.ended_at IS NULL AND contexts.id IS NULL

          UNION ALL

          SELECT 'subscription_revision_mismatch' AS issue_type
          FROM entitlement_subscription_contexts contexts
          JOIN subscriptions subscriptions
            ON subscriptions.organization_id = contexts.organization_id
            AND subscriptions.id = contexts.subscription_id
          WHERE contexts.active = TRUE
            AND contexts.subscription_revision <> subscriptions.lock_version

          UNION ALL

          SELECT 'subscription_projection_mismatch' AS issue_type
          FROM entitlement_subscription_contexts contexts
          JOIN subscriptions subscriptions
            ON subscriptions.organization_id = contexts.organization_id
            AND subscriptions.id = contexts.subscription_id
          WHERE contexts.active = TRUE AND (
            contexts.plan_version_id IS DISTINCT FROM subscriptions.plan_version_id
            OR contexts.subscription_status IS DISTINCT FROM subscriptions.status
            OR contexts.access_state IS DISTINCT FROM subscriptions.access_state
            OR contexts.grace_ends_at IS DISTINCT FROM subscriptions.grace_ends_at
            OR contexts.access_expires_at IS DISTINCT FROM subscriptions.access_expires_at
          )
        ) issues
        GROUP BY issue_type
      SQL
      counts = rows.to_h { |row| [ row.fetch("issue_type"), row.fetch("issue_count").to_i ] }
      ISSUE_TYPES.filter_map do |type|
        count = counts.fetch(type, 0)
        { type: type, count: count }.freeze if count.positive?
      end.freeze
    end
  end
end
