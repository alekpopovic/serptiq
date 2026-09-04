# frozen_string_literal: true

class CreateBillingWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_webhook_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :provider, limit: 32, null: false
      t.string :environment, limit: 16, null: false
      t.string :provider_event_id, limit: 191, null: false
      t.string :event_type, limit: 64, null: false
      t.string :payload_checksum, limit: 64, null: false
      t.text :payload_ciphertext, null: false
      t.jsonb :request_headers, null: false, default: {}
      t.string :state, limit: 16, null: false, default: "pending"
      t.integer :attempt_count, null: false, default: 0
      t.integer :duplicate_count, null: false, default: 0
      t.integer :conflict_count, null: false, default: 0
      t.string :last_error_category, limit: 64
      t.datetime :received_at, null: false
      t.datetime :last_received_at, null: false
      t.datetime :last_attempted_at
      t.datetime :processed_at
      t.datetime :failed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :billing_webhook_events, %i[provider environment provider_event_id], unique: true,
      name: "index_billing_webhooks_on_provider_event"
    add_index :billing_webhook_events, %i[state received_at],
      name: "index_billing_webhooks_on_state_received"
    add_index :billing_webhook_events, :payload_checksum,
      name: "index_billing_webhooks_on_payload_checksum"

    add_check_constraint :billing_webhook_events,
      "provider ~ '^[a-z][a-z0-9_]{1,31}$'",
      name: "billing_webhooks_provider_format"
    add_check_constraint :billing_webhook_events,
      "environment IN ('development', 'test', 'staging', 'production')",
      name: "billing_webhooks_environment_allowlist"
    add_check_constraint :billing_webhook_events,
      "provider_event_id ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,190}$'",
      name: "billing_webhooks_event_id_format"
    add_check_constraint :billing_webhook_events,
      "event_type ~ '^[a-z][a-z0-9_.-]{0,63}$'",
      name: "billing_webhooks_event_type_format"
    add_check_constraint :billing_webhook_events,
      "payload_checksum ~ '^[0-9a-f]{64}$'",
      name: "billing_webhooks_checksum_format"
    add_check_constraint :billing_webhook_events,
      "octet_length(payload_ciphertext) BETWEEN 1 AND 1048576",
      name: "billing_webhooks_ciphertext_size"
    add_check_constraint :billing_webhook_events,
      "jsonb_typeof(request_headers) = 'object'",
      name: "billing_webhooks_headers_object"
    add_check_constraint :billing_webhook_events,
      "state IN ('pending', 'processing', 'processed', 'retryable', 'dead_letter')",
      name: "billing_webhooks_state_allowlist"
    add_check_constraint :billing_webhook_events,
      "attempt_count >= 0 AND duplicate_count >= 0 AND conflict_count >= 0",
      name: "billing_webhooks_nonnegative_counts"
    add_check_constraint :billing_webhook_events,
      "last_received_at >= received_at",
      name: "billing_webhooks_receive_order"
    add_check_constraint :billing_webhook_events, lifecycle_shape_sql,
      name: "billing_webhooks_lifecycle_shape"
  end

  private

  def lifecycle_shape_sql
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
