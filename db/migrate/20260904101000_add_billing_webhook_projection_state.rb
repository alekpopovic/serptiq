# frozen_string_literal: true

class AddBillingWebhookProjectionState < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :billing_webhook_events, name: "billing_webhooks_lifecycle_shape"

    add_column :billing_webhook_events, :parser_version, :integer, null: false, default: 1
    add_column :billing_webhook_events, :processing_result, :string, limit: 24
    add_column :billing_webhook_events, :replay_count, :integer, null: false, default: 0
    add_column :billing_webhook_events, :next_attempt_at, :datetime
    add_column :billing_webhook_events, :organization_id, :uuid
    add_column :billing_webhook_events, :subscription_id, :uuid

    add_column :subscriptions, :provider_event_precedence, :integer, null: false, default: 0
    add_column :subscriptions, :provider_event_digest, :string, limit: 64

    add_index :billing_webhook_events, %i[state next_attempt_at],
      name: "index_billing_webhooks_on_retry_schedule"
    add_index :billing_webhook_events, %i[organization_id received_at],
      name: "index_billing_webhooks_on_tenant_received"
    add_index :subscriptions, %i[organization_id id], unique: true,
      name: "index_subscriptions_on_tenant_identity"

    add_foreign_key :billing_webhook_events, :organizations, on_delete: :restrict
    add_foreign_key :billing_webhook_events, :subscriptions,
      column: %i[organization_id subscription_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_billing_webhooks_tenant_subscription"

    add_check_constraint :billing_webhook_events,
      "parser_version BETWEEN 1 AND 32767",
      name: "billing_webhooks_parser_version_range"
    add_check_constraint :billing_webhook_events,
      "processing_result IS NULL OR processing_result IN ('applied', 'stale', 'observed', 'ignored')",
      name: "billing_webhooks_result_allowlist"
    add_check_constraint :billing_webhook_events,
      "replay_count >= 0",
      name: "billing_webhooks_nonnegative_replays"
    add_check_constraint :billing_webhook_events,
      "subscription_id IS NULL OR organization_id IS NOT NULL",
      name: "billing_webhooks_subscription_tenant_present"
    add_check_constraint :billing_webhook_events, lifecycle_shape_sql,
      name: "billing_webhooks_lifecycle_shape"
    add_check_constraint :subscriptions,
      "provider_event_precedence >= 0",
      name: "subscriptions_provider_event_precedence_nonnegative"
    add_check_constraint :subscriptions,
      "provider_event_digest IS NULL OR provider_event_digest ~ '^[0-9a-f]{64}$'",
      name: "subscriptions_provider_event_digest_format"
  end

  def down
    remove_check_constraint :subscriptions, name: "subscriptions_provider_event_digest_format"
    remove_check_constraint :subscriptions, name: "subscriptions_provider_event_precedence_nonnegative"
    remove_check_constraint :billing_webhook_events, name: "billing_webhooks_lifecycle_shape"
    remove_check_constraint :billing_webhook_events, name: "billing_webhooks_subscription_tenant_present"
    remove_check_constraint :billing_webhook_events, name: "billing_webhooks_nonnegative_replays"
    remove_check_constraint :billing_webhook_events, name: "billing_webhooks_result_allowlist"
    remove_check_constraint :billing_webhook_events, name: "billing_webhooks_parser_version_range"
    remove_foreign_key :billing_webhook_events, name: "fk_billing_webhooks_tenant_subscription"
    remove_foreign_key :billing_webhook_events, :organizations
    remove_index :subscriptions, name: "index_subscriptions_on_tenant_identity"
    remove_index :billing_webhook_events, name: "index_billing_webhooks_on_tenant_received"
    remove_index :billing_webhook_events, name: "index_billing_webhooks_on_retry_schedule"

    remove_column :subscriptions, :provider_event_digest
    remove_column :subscriptions, :provider_event_precedence
    %i[subscription_id organization_id next_attempt_at replay_count processing_result parser_version].each do |column|
      remove_column :billing_webhook_events, column
    end

    add_check_constraint :billing_webhook_events, original_lifecycle_shape_sql,
      name: "billing_webhooks_lifecycle_shape"
  end

  private

  def lifecycle_shape_sql
    <<~SQL.squish
      (state = 'pending' AND processed_at IS NULL AND failed_at IS NULL
        AND last_error_category IS NULL AND processing_result IS NULL
        AND ((attempt_count = 0 AND last_attempted_at IS NULL)
          OR (attempt_count > 0 AND last_attempted_at IS NOT NULL AND replay_count > 0)))
      OR
      (state = 'processing' AND attempt_count > 0 AND last_attempted_at IS NOT NULL
        AND processed_at IS NULL AND failed_at IS NULL AND last_error_category IS NULL
        AND processing_result IS NULL AND next_attempt_at IS NULL)
      OR
      (state = 'processed' AND attempt_count > 0 AND last_attempted_at IS NOT NULL
        AND processed_at IS NOT NULL AND failed_at IS NULL AND last_error_category IS NULL
        AND processing_result IS NOT NULL AND next_attempt_at IS NULL)
      OR
      (state IN ('retryable', 'dead_letter') AND attempt_count > 0 AND last_attempted_at IS NOT NULL
        AND processed_at IS NULL AND failed_at IS NOT NULL AND last_error_category IS NOT NULL
        AND processing_result IS NULL
        AND ((state = 'retryable' AND next_attempt_at IS NOT NULL)
          OR (state = 'dead_letter' AND next_attempt_at IS NULL)))
    SQL
  end

  def original_lifecycle_shape_sql
    <<~SQL.squish
      (state = 'pending' AND attempt_count = 0 AND last_attempted_at IS NULL
        AND processed_at IS NULL AND failed_at IS NULL AND last_error_category IS NULL)
      OR
      (state = 'processing' AND attempt_count > 0 AND last_attempted_at IS NOT NULL
        AND processed_at IS NULL AND failed_at IS NULL AND last_error_category IS NULL)
      OR
      (state = 'processed' AND attempt_count > 0 AND last_attempted_at IS NOT NULL
        AND processed_at IS NOT NULL AND failed_at IS NULL AND last_error_category IS NULL)
      OR
      (state IN ('retryable', 'dead_letter') AND attempt_count > 0 AND last_attempted_at IS NOT NULL
        AND processed_at IS NULL AND failed_at IS NOT NULL AND last_error_category IS NOT NULL)
    SQL
  end
end
