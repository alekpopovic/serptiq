# frozen_string_literal: true

class ImplementSubscriptionLifecycleAccess < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :subscriptions, name: "subscriptions_status_allowlist"
    remove_check_constraint :subscriptions, name: "subscriptions_status_access_shape"
    remove_check_constraint :subscriptions, name: "subscriptions_period_shape"

    add_column :subscriptions, :grace_ends_at, :datetime
    add_column :subscriptions, :access_expires_at, :datetime
    add_check_constraint :subscriptions,
      "status IN ('pending', 'incomplete', 'trialing', 'active', 'past_due', 'paused', 'canceled', 'expired')",
      name: "subscriptions_status_allowlist"
    add_check_constraint :subscriptions, subscription_status_access_sql,
      name: "subscriptions_status_access_shape"
    add_check_constraint :subscriptions, subscription_access_timing_sql,
      name: "subscriptions_access_timing_shape"
    add_check_constraint :subscriptions, subscription_period_sql,
      name: "subscriptions_period_shape"

    add_column :entitlement_subscription_contexts, :subscription_status, :string, limit: 24
    add_column :entitlement_subscription_contexts, :access_state, :string, limit: 24
    add_column :entitlement_subscription_contexts, :grace_ends_at, :datetime
    add_column :entitlement_subscription_contexts, :access_expires_at, :datetime
    execute <<~SQL
      UPDATE entitlement_subscription_contexts contexts
      SET subscription_status = subscriptions.status,
          access_state = subscriptions.access_state,
          grace_ends_at = subscriptions.grace_ends_at,
          access_expires_at = subscriptions.access_expires_at
      FROM subscriptions
      WHERE subscriptions.id = contexts.subscription_id
    SQL
    change_column_null :entitlement_subscription_contexts, :subscription_status, false
    change_column_null :entitlement_subscription_contexts, :access_state, false
    add_check_constraint :entitlement_subscription_contexts,
      "subscription_status IN ('pending', 'incomplete', 'trialing', 'active', 'past_due', 'paused', 'canceled', 'expired')",
      name: "entitlement_contexts_subscription_status_allowlist"
    add_check_constraint :entitlement_subscription_contexts,
      "access_state IN ('pending', 'full', 'grace', 'read_only', 'suspended')",
      name: "entitlement_contexts_access_state_allowlist"
    replace_entitlement_context_foreign_key(deferrable: :deferred)
    replace_usage_subscription_snapshot_foreign_keys(snapshot_mode: false)

    create_subscription_changes
    create_outbox_events
  end

  def down
    drop_table :outbox_events
    drop_table :billing_subscription_changes

    replace_usage_subscription_snapshot_foreign_keys(snapshot_mode: true)
    replace_entitlement_context_foreign_key(deferrable: false)

    remove_check_constraint :entitlement_subscription_contexts,
      name: "entitlement_contexts_access_state_allowlist"
    remove_check_constraint :entitlement_subscription_contexts,
      name: "entitlement_contexts_subscription_status_allowlist"
    remove_column :entitlement_subscription_contexts, :access_expires_at
    remove_column :entitlement_subscription_contexts, :grace_ends_at
    remove_column :entitlement_subscription_contexts, :access_state
    remove_column :entitlement_subscription_contexts, :subscription_status

    remove_check_constraint :subscriptions, name: "subscriptions_access_timing_shape"
    remove_check_constraint :subscriptions, name: "subscriptions_status_access_shape"
    remove_check_constraint :subscriptions, name: "subscriptions_status_allowlist"
    remove_check_constraint :subscriptions, name: "subscriptions_period_shape"
    execute "UPDATE subscriptions SET status = 'pending' WHERE status = 'incomplete'"
    execute "UPDATE subscriptions SET current_period_ends_at = NULL WHERE current_period_starts_at IS NULL"
    remove_column :subscriptions, :access_expires_at
    remove_column :subscriptions, :grace_ends_at
    add_check_constraint :subscriptions,
      "status IN ('pending', 'trialing', 'active', 'past_due', 'paused', 'canceled', 'expired')",
      name: "subscriptions_status_allowlist"
    add_check_constraint :subscriptions, original_status_access_sql,
      name: "subscriptions_status_access_shape"
    add_check_constraint :subscriptions, original_period_sql,
      name: "subscriptions_period_shape"
  end

  private

  def replace_entitlement_context_foreign_key(deferrable:)
    remove_foreign_key :entitlement_subscription_contexts,
      name: "fk_entitlement_contexts_subscription_identity"
    add_foreign_key :entitlement_subscription_contexts, :subscriptions,
      column: %i[organization_id subscription_id plan_version_id],
      primary_key: %i[organization_id id plan_version_id],
      on_delete: :restrict,
      deferrable: deferrable,
      name: "fk_entitlement_contexts_subscription_identity"
  end

  def replace_usage_subscription_snapshot_foreign_keys(snapshot_mode:)
    remove_foreign_key :usage_quota_reservations,
      name: "fk_usage_quota_reservations_subscription_snapshot"
    remove_foreign_key :usage_windows, name: "fk_usage_windows_subscription_snapshot"
    remove_foreign_key :usage_windows, name: "fk_usage_windows_plan_version" if
      foreign_key_exists?(:usage_windows, :plan_versions, name: "fk_usage_windows_plan_version")

    columns = snapshot_mode ? %i[organization_id subscription_id plan_version_id] :
      %i[organization_id subscription_id]
    primary = snapshot_mode ? %i[organization_id id plan_version_id] : %i[organization_id id]
    add_foreign_key :usage_quota_reservations, :subscriptions,
      column: columns,
      primary_key: primary,
      on_delete: :restrict,
      name: "fk_usage_quota_reservations_subscription_snapshot"
    add_foreign_key :usage_windows, :subscriptions,
      column: columns,
      primary_key: primary,
      on_delete: :restrict,
      name: "fk_usage_windows_subscription_snapshot"
    unless snapshot_mode
      add_foreign_key :usage_windows, :plan_versions,
        on_delete: :restrict,
        name: "fk_usage_windows_plan_version"
    end
  end

  def create_subscription_changes
    create_table :billing_subscription_changes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :subscription_id, null: false
      t.uuid :from_plan_version_id, null: false
      t.uuid :target_plan_version_id, null: false
      t.uuid :requested_by_membership_id, null: false
      t.string :target_billing_interval, limit: 16, null: false
      t.string :direction, limit: 16, null: false
      t.string :effective_policy, limit: 16, null: false
      t.string :state, limit: 16, null: false
      t.string :idempotency_digest, limit: 64, null: false
      t.string :request_checksum, limit: 64, null: false
      t.datetime :requested_at, null: false
      t.datetime :effective_at, null: false
      t.datetime :dispatch_enqueued_at
      t.datetime :submitted_at
      t.datetime :applied_at
      t.datetime :failed_at
      t.string :failure_category, limit: 64
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_foreign_key :billing_subscription_changes, :organizations, on_delete: :restrict
    add_foreign_key :billing_subscription_changes, :subscriptions,
      column: %i[organization_id subscription_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_billing_changes_tenant_subscription"
    add_foreign_key :billing_subscription_changes, :memberships,
      column: %i[organization_id requested_by_membership_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_billing_changes_tenant_requester"
    add_foreign_key :billing_subscription_changes, :plan_versions,
      column: :from_plan_version_id, on_delete: :restrict
    add_foreign_key :billing_subscription_changes, :plan_versions,
      column: :target_plan_version_id, on_delete: :restrict
    add_index :billing_subscription_changes, %i[organization_id idempotency_digest], unique: true,
      name: "index_billing_changes_on_tenant_idempotency"
    add_index :billing_subscription_changes, :subscription_id, unique: true,
      where: "state IN ('pending', 'scheduled', 'submitted')",
      name: "index_billing_changes_on_active_subscription"
    add_index :billing_subscription_changes, %i[state effective_at],
      name: "index_billing_changes_on_dispatch"
    add_check_constraint :billing_subscription_changes,
      "from_plan_version_id <> target_plan_version_id",
      name: "billing_changes_distinct_plan_versions"
    add_check_constraint :billing_subscription_changes,
      "target_billing_interval IN ('monthly', 'annual')",
      name: "billing_changes_interval_allowlist"
    add_check_constraint :billing_subscription_changes,
      "direction IN ('upgrade', 'downgrade')",
      name: "billing_changes_direction_allowlist"
    add_check_constraint :billing_subscription_changes,
      "effective_policy IN ('immediate', 'period_end')",
      name: "billing_changes_policy_allowlist"
    add_check_constraint :billing_subscription_changes,
      "state IN ('pending', 'scheduled', 'submitted', 'applied', 'failed', 'canceled')",
      name: "billing_changes_state_allowlist"
    add_check_constraint :billing_subscription_changes,
      "idempotency_digest ~ '^[0-9a-f]{64}$' AND request_checksum ~ '^[0-9a-f]{64}$'",
      name: "billing_changes_digest_format"
    add_check_constraint :billing_subscription_changes, subscription_change_lifecycle_sql,
      name: "billing_changes_lifecycle_shape"
  end

  def create_outbox_events
    create_table :outbox_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.string :aggregate_type, limit: 48, null: false
      t.uuid :aggregate_id, null: false
      t.string :event_type, limit: 96, null: false
      t.integer :event_version, null: false, default: 1
      t.jsonb :payload, null: false, default: {}
      t.string :idempotency_key, limit: 64, null: false
      t.datetime :occurred_at, null: false
      t.datetime :published_at
      t.integer :attempt_count, null: false, default: 0
      t.datetime :last_attempted_at
      t.string :last_error_category, limit: 64
      t.timestamps
    end
    add_foreign_key :outbox_events, :organizations, on_delete: :restrict
    add_index :outbox_events, :idempotency_key, unique: true
    add_index :outbox_events, %i[published_at occurred_at]
    add_check_constraint :outbox_events,
      "aggregate_type ~ '^[A-Z][A-Za-z0-9]{0,47}$'",
      name: "outbox_events_aggregate_type_format"
    add_check_constraint :outbox_events,
      "event_type ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'",
      name: "outbox_events_event_type_format"
    add_check_constraint :outbox_events,
      "event_version > 0 AND attempt_count >= 0",
      name: "outbox_events_positive_counters"
    add_check_constraint :outbox_events,
      "idempotency_key ~ '^[0-9a-f]{64}$'",
      name: "outbox_events_idempotency_format"
    add_check_constraint :outbox_events,
      "jsonb_typeof(payload) = 'object' AND pg_column_size(payload) <= 8192",
      name: "outbox_events_payload_bounded"
    add_check_constraint :outbox_events,
      "(published_at IS NULL) OR (last_attempted_at IS NOT NULL AND last_error_category IS NULL)",
      name: "outbox_events_publish_shape"
  end

  def subscription_status_access_sql
    <<~SQL.squish
      (status IN ('pending', 'incomplete') AND access_state = 'pending')
      OR (status IN ('trialing', 'active') AND access_state = 'full')
      OR (status = 'past_due' AND access_state IN ('grace', 'read_only'))
      OR (status = 'paused' AND access_state IN ('read_only', 'suspended'))
      OR (status = 'canceled' AND access_state IN ('full', 'read_only'))
      OR (status = 'expired' AND access_state = 'read_only')
    SQL
  end

  def subscription_access_timing_sql
    <<~SQL.squish
      ((status = 'past_due' AND grace_ends_at IS NOT NULL) OR
        (status <> 'past_due' AND grace_ends_at IS NULL))
      AND ((status = 'canceled' AND access_expires_at IS NOT NULL) OR
        (status <> 'canceled' AND access_expires_at IS NULL))
    SQL
  end

  def subscription_period_sql
    <<~SQL.squish
      (current_period_starts_at IS NULL AND current_period_ends_at IS NULL)
      OR (current_period_ends_at IS NOT NULL AND
        (current_period_starts_at IS NULL OR current_period_ends_at > current_period_starts_at))
    SQL
  end

  def subscription_change_lifecycle_sql
    <<~SQL.squish
      effective_at >= requested_at
      AND (dispatch_enqueued_at IS NULL OR dispatch_enqueued_at >= requested_at)
      AND ((direction = 'upgrade' AND effective_policy = 'immediate' AND state <> 'scheduled')
        OR (direction = 'downgrade' AND effective_policy = 'period_end' AND state <> 'pending'))
      AND ((state IN ('pending', 'scheduled') AND submitted_at IS NULL AND applied_at IS NULL
          AND failed_at IS NULL AND failure_category IS NULL)
        OR (state = 'submitted' AND submitted_at IS NOT NULL AND applied_at IS NULL
          AND failed_at IS NULL AND failure_category IS NULL)
        OR (state = 'applied' AND submitted_at IS NOT NULL AND applied_at IS NOT NULL
          AND failed_at IS NULL AND failure_category IS NULL)
        OR (state = 'failed' AND applied_at IS NULL AND failed_at IS NOT NULL
          AND failure_category IS NOT NULL)
        OR (state = 'canceled' AND applied_at IS NULL AND failed_at IS NULL
          AND failure_category IS NULL))
    SQL
  end

  def original_status_access_sql
    <<~SQL.squish
      (status = 'pending' AND access_state = 'pending')
      OR (status IN ('trialing', 'active') AND access_state = 'full')
      OR (status = 'past_due' AND access_state IN ('grace', 'read_only'))
      OR (status = 'paused' AND access_state IN ('read_only', 'suspended'))
      OR (status = 'canceled' AND access_state IN ('full', 'read_only'))
      OR (status = 'expired' AND access_state = 'read_only')
    SQL
  end

  def original_period_sql
    <<~SQL.squish
      (current_period_starts_at IS NULL AND current_period_ends_at IS NULL)
      OR (current_period_starts_at IS NOT NULL AND current_period_ends_at IS NOT NULL
        AND current_period_ends_at > current_period_starts_at)
    SQL
  end
end
