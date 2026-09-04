# frozen_string_literal: true

class CreateBillingCheckoutSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_checkout_sessions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :plan_version_id, null: false
      t.uuid :actor_membership_id, null: false
      t.uuid :billing_customer_id
      t.string :provider, limit: 32, null: false
      t.string :environment, limit: 16, null: false
      t.string :currency, limit: 3, null: false
      t.string :billing_interval, limit: 16, null: false
      t.string :state, limit: 16, null: false, default: "preparing"
      t.string :idempotency_digest, limit: 64, null: false
      t.string :provider_checkout_id, limit: 191
      t.string :failure_category, limit: 64
      t.datetime :expires_at, null: false
      t.datetime :ready_at
      t.datetime :failed_at
      t.timestamps
    end

    add_foreign_key :billing_checkout_sessions, :organizations, on_delete: :restrict
    add_foreign_key :billing_checkout_sessions, :plan_versions, on_delete: :restrict
    add_foreign_key :billing_checkout_sessions, :memberships,
      column: %i[organization_id actor_membership_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_billing_checkouts_tenant_membership"
    add_foreign_key :billing_checkout_sessions, :billing_customers,
      column: %i[billing_customer_id organization_id provider environment],
      primary_key: %i[id organization_id provider environment], on_delete: :restrict,
      name: "fk_billing_checkouts_tenant_customer"

    add_index :billing_checkout_sessions, %i[organization_id id], unique: true,
      name: "index_billing_checkouts_on_tenant_identity"
    add_index :billing_checkout_sessions, %i[organization_id idempotency_digest], unique: true,
      name: "index_billing_checkouts_on_tenant_idempotency"
    add_index :billing_checkout_sessions, :organization_id, unique: true,
      where: "state IN ('preparing', 'ready', 'uncertain')",
      name: "index_billing_checkouts_on_active_tenant"
    add_index :billing_checkout_sessions, %i[provider environment provider_checkout_id], unique: true,
      where: "provider_checkout_id IS NOT NULL",
      name: "index_billing_checkouts_on_provider_identity"

    add_check_constraint :billing_checkout_sessions,
      "provider ~ '^[a-z][a-z0-9_]{1,31}$'",
      name: "billing_checkouts_provider_format"
    add_check_constraint :billing_checkout_sessions,
      "environment IN ('development', 'test', 'staging', 'production')",
      name: "billing_checkouts_environment_allowlist"
    add_check_constraint :billing_checkout_sessions,
      "currency ~ '^[A-Z]{3}$'",
      name: "billing_checkouts_currency_format"
    add_check_constraint :billing_checkout_sessions,
      "billing_interval IN ('monthly', 'annual')",
      name: "billing_checkouts_interval_allowlist"
    add_check_constraint :billing_checkout_sessions,
      "state IN ('preparing', 'ready', 'uncertain', 'failed', 'expired')",
      name: "billing_checkouts_state_allowlist"
    add_check_constraint :billing_checkout_sessions,
      "idempotency_digest ~ '^[0-9a-f]{64}$'",
      name: "billing_checkouts_idempotency_digest_format"
    add_check_constraint :billing_checkout_sessions,
      "provider_checkout_id IS NULL OR provider_checkout_id ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,190}$'",
      name: "billing_checkouts_provider_id_format"
    add_check_constraint :billing_checkout_sessions,
      "failure_category IS NULL OR failure_category ~ '^[a-z][a-z0-9_]{0,63}$'",
      name: "billing_checkouts_failure_category_format"
    add_check_constraint :billing_checkout_sessions,
      "expires_at > created_at",
      name: "billing_checkouts_expiration_order"
    add_check_constraint :billing_checkout_sessions, lifecycle_shape_sql,
      name: "billing_checkouts_lifecycle_shape"
  end

  private

  def lifecycle_shape_sql
    <<~SQL.squish
      (state = 'preparing' AND provider_checkout_id IS NULL AND ready_at IS NULL
        AND failed_at IS NULL AND failure_category IS NULL)
      OR
      (state = 'ready' AND billing_customer_id IS NOT NULL AND provider_checkout_id IS NOT NULL
        AND ready_at IS NOT NULL AND failed_at IS NULL AND failure_category IS NULL)
      OR
      (state = 'uncertain' AND provider_checkout_id IS NULL AND ready_at IS NULL
        AND failed_at IS NOT NULL AND failure_category IS NOT NULL)
      OR
      (state = 'failed' AND provider_checkout_id IS NULL AND ready_at IS NULL
        AND failed_at IS NOT NULL AND failure_category IS NOT NULL)
      OR
      (state = 'expired')
    SQL
  end
end
