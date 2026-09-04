# frozen_string_literal: true

class AddBillingReconciliationSupport < ActiveRecord::Migration[8.1]
  def change
    create_support_access_grants
    create_reconciliation_runs
  end

  private

  def create_support_access_grants
    create_table :billing_support_access_grants, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :permission, limit: 32, null: false
      t.datetime :granted_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_foreign_key :billing_support_access_grants, :users, on_delete: :restrict
    add_index :billing_support_access_grants, %i[user_id permission], unique: true,
      where: "revoked_at IS NULL", name: "index_billing_support_grants_on_active_permission"
    add_check_constraint :billing_support_access_grants,
      "permission IN ('billing_support.read', 'billing_support.manage')",
      name: "billing_support_grants_permission_allowlist"
    add_check_constraint :billing_support_access_grants,
      "revoked_at IS NULL OR revoked_at >= granted_at",
      name: "billing_support_grants_revocation_order"
  end

  def create_reconciliation_runs
    create_table :billing_reconciliation_runs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :subscription_id, null: false
      t.uuid :requested_by_user_id
      t.string :provider, limit: 32, null: false
      t.string :environment, limit: 16, null: false
      t.string :source, limit: 16, null: false
      t.string :state, limit: 16, null: false, default: "queued"
      t.jsonb :provider_snapshot, null: false, default: {}
      t.jsonb :difference_fields, null: false, default: []
      t.string :failure_category, limit: 64
      t.datetime :requested_at, null: false
      t.datetime :enqueued_at
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :next_attempt_at
      t.datetime :provider_updated_at
      t.integer :attempt_count, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_foreign_key :billing_reconciliation_runs, :organizations, on_delete: :restrict
    add_foreign_key :billing_reconciliation_runs, :subscriptions,
      column: %i[organization_id subscription_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_billing_reconciliations_tenant_subscription"
    add_foreign_key :billing_reconciliation_runs, :users,
      column: :requested_by_user_id, on_delete: :restrict
    add_index :billing_reconciliation_runs, :subscription_id, unique: true,
      where: "state IN ('queued', 'running', 'retryable')",
      name: "index_billing_reconciliations_on_active_subscription"
    add_index :billing_reconciliation_runs, %i[provider environment requested_at],
      name: "index_billing_reconciliations_on_provider_rate"
    add_index :billing_reconciliation_runs, %i[state next_attempt_at],
      name: "index_billing_reconciliations_on_retry"
    add_index :billing_reconciliation_runs, %i[organization_id requested_at],
      name: "index_billing_reconciliations_on_tenant_history"
    add_check_constraint :billing_reconciliation_runs,
      "provider ~ '^[a-z][a-z0-9_]{1,31}$'",
      name: "billing_reconciliations_provider_format"
    add_check_constraint :billing_reconciliation_runs,
      "environment IN ('development', 'test', 'staging', 'production')",
      name: "billing_reconciliations_environment_allowlist"
    add_check_constraint :billing_reconciliation_runs,
      "source IN ('scheduled', 'targeted')",
      name: "billing_reconciliations_source_allowlist"
    add_check_constraint :billing_reconciliation_runs,
      "state IN ('queued', 'running', 'matched', 'repaired', 'ambiguous', 'missing', 'retryable', 'failed')",
      name: "billing_reconciliations_state_allowlist"
    add_check_constraint :billing_reconciliation_runs,
      "attempt_count BETWEEN 0 AND 5",
      name: "billing_reconciliations_attempt_range"
    add_check_constraint :billing_reconciliation_runs,
      "enqueued_at IS NULL OR enqueued_at >= requested_at",
      name: "billing_reconciliations_enqueue_order"
    add_check_constraint :billing_reconciliation_runs,
      "jsonb_typeof(provider_snapshot) = 'object' AND pg_column_size(provider_snapshot) <= 8192",
      name: "billing_reconciliations_snapshot_bounded"
    add_check_constraint :billing_reconciliation_runs,
      "jsonb_typeof(difference_fields) = 'array' AND pg_column_size(difference_fields) <= 2048",
      name: "billing_reconciliations_differences_bounded"
    add_check_constraint :billing_reconciliation_runs,
      "(source = 'scheduled' AND requested_by_user_id IS NULL) OR " \
        "(source = 'targeted' AND requested_by_user_id IS NOT NULL)",
      name: "billing_reconciliations_requester_shape"
    add_check_constraint :billing_reconciliation_runs, reconciliation_lifecycle_sql,
      name: "billing_reconciliations_lifecycle_shape"
  end

  def reconciliation_lifecycle_sql
    <<~SQL.squish
      (state = 'queued' AND attempt_count = 0 AND started_at IS NULL AND completed_at IS NULL
        AND next_attempt_at IS NULL AND failure_category IS NULL)
      OR (state = 'running' AND attempt_count > 0 AND started_at IS NOT NULL AND completed_at IS NULL
        AND next_attempt_at IS NULL AND failure_category IS NULL)
      OR (state = 'retryable' AND attempt_count > 0 AND started_at IS NOT NULL AND completed_at IS NULL
        AND next_attempt_at IS NOT NULL AND failure_category IS NOT NULL)
      OR (state IN ('matched', 'repaired', 'ambiguous') AND attempt_count > 0
        AND started_at IS NOT NULL AND completed_at IS NOT NULL AND next_attempt_at IS NULL
        AND failure_category IS NULL)
      OR (state IN ('missing', 'failed') AND attempt_count > 0
        AND started_at IS NOT NULL AND completed_at IS NOT NULL AND next_attempt_at IS NULL
        AND failure_category IS NOT NULL)
    SQL
  end
end
