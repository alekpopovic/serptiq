# frozen_string_literal: true

class CreateProviderNeutralBillingDomain < ActiveRecord::Migration[8.1]
  def up
    create_customer_mappings
    extend_subscriptions
  end

  def down
    collapse_subscription_lifecycle
    remove_extended_subscriptions
    drop_table :billing_customers
    execute "DROP FUNCTION IF EXISTS enforce_billing_customer_mapping_immutability()"
  end

  private

  def create_customer_mappings
    create_table :billing_customers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.string :provider, limit: 32, null: false
      t.string :environment, limit: 16, null: false
      t.string :provider_customer_id, limit: 191, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    add_foreign_key :billing_customers, :organizations, on_delete: :restrict
    add_index :billing_customers, %i[organization_id provider environment], unique: true,
      name: "index_billing_customers_on_tenant_provider"
    add_index :billing_customers, %i[provider environment provider_customer_id], unique: true,
      name: "index_billing_customers_on_provider_identity"
    add_index :billing_customers, %i[id organization_id provider environment], unique: true,
      name: "index_billing_customers_on_composite_identity"
    add_check_constraint :billing_customers,
      "provider ~ '^[a-z][a-z0-9_]{1,31}$'",
      name: "billing_customers_provider_format"
    add_check_constraint :billing_customers,
      "environment IN ('development', 'test', 'staging', 'production')",
      name: "billing_customers_environment_allowlist"
    add_check_constraint :billing_customers,
      "provider_customer_id ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,190}$'",
      name: "billing_customers_provider_id_format"
    install_customer_mapping_guard
  end

  def extend_subscriptions
    remove_check_constraint :subscriptions, name: "subscriptions_status_allowlist"
    remove_check_constraint :subscriptions, name: "subscriptions_lifecycle_shape"
    remove_index :subscriptions, name: "index_subscriptions_on_active_organization"

    add_column :subscriptions, :billing_customer_id, :uuid
    add_column :subscriptions, :provider, :string, limit: 32
    add_column :subscriptions, :provider_environment, :string, limit: 16
    add_column :subscriptions, :provider_subscription_id, :string, limit: 191
    add_column :subscriptions, :access_state, :string, limit: 24, null: false, default: "full"
    add_column :subscriptions, :provider_metadata, :jsonb, null: false, default: {}
    add_column :subscriptions, :current_period_starts_at, :datetime
    add_column :subscriptions, :current_period_ends_at, :datetime
    add_column :subscriptions, :trial_ends_at, :datetime
    add_column :subscriptions, :cancel_at_period_end, :boolean, null: false, default: false
    add_column :subscriptions, :canceled_at, :datetime
    add_column :subscriptions, :provider_updated_at, :datetime
    add_column :subscriptions, :last_synced_at, :datetime

    execute <<~SQL
      UPDATE subscriptions
      SET status = 'expired', access_state = 'read_only'
      WHERE status = 'inactive'
    SQL

    add_foreign_key :subscriptions, :billing_customers,
      column: %i[billing_customer_id organization_id provider provider_environment],
      primary_key: %i[id organization_id provider environment], on_delete: :restrict,
      name: "fk_subscriptions_tenant_provider_customer"
    add_index :subscriptions, :organization_id, unique: true,
      where: "ended_at IS NULL", name: "index_subscriptions_on_current_organization"
    add_index :subscriptions, %i[provider provider_environment provider_subscription_id], unique: true,
      where: "provider_subscription_id IS NOT NULL",
      name: "index_subscriptions_on_provider_identity"
    add_check_constraint :subscriptions,
      "status IN ('pending', 'trialing', 'active', 'past_due', 'paused', 'canceled', 'expired')",
      name: "subscriptions_status_allowlist"
    add_check_constraint :subscriptions,
      "access_state IN ('pending', 'full', 'grace', 'read_only', 'suspended')",
      name: "subscriptions_access_state_allowlist"
    add_check_constraint :subscriptions, provider_shape_sql,
      name: "subscriptions_provider_shape"
    add_check_constraint :subscriptions,
      "jsonb_typeof(provider_metadata) = 'object' AND pg_column_size(provider_metadata) <= 4096",
      name: "subscriptions_provider_metadata_bounded"
    add_check_constraint :subscriptions, lifecycle_shape_sql,
      name: "subscriptions_lifecycle_shape"
    add_check_constraint :subscriptions, period_shape_sql,
      name: "subscriptions_period_shape"
    add_check_constraint :subscriptions, status_access_shape_sql,
      name: "subscriptions_status_access_shape"
    add_check_constraint :subscriptions, cancellation_shape_sql,
      name: "subscriptions_cancellation_shape"
    add_check_constraint :subscriptions,
      "trial_ends_at IS NULL OR trial_ends_at >= started_at",
      name: "subscriptions_trial_end_order"
    add_check_constraint :subscriptions,
      "last_synced_at IS NULL OR provider_updated_at IS NULL OR last_synced_at >= provider_updated_at",
      name: "subscriptions_provider_sync_order"
  end

  def collapse_subscription_lifecycle
    execute <<~SQL
      UPDATE subscriptions
      SET status = 'inactive', ended_at = COALESCE(ended_at, CURRENT_TIMESTAMP)
      WHERE status <> 'active'
    SQL
  end

  def remove_extended_subscriptions
    remove_check_constraint :subscriptions, name: "subscriptions_provider_sync_order"
    remove_check_constraint :subscriptions, name: "subscriptions_trial_end_order"
    remove_check_constraint :subscriptions, name: "subscriptions_cancellation_shape"
    remove_check_constraint :subscriptions, name: "subscriptions_status_access_shape"
    remove_check_constraint :subscriptions, name: "subscriptions_period_shape"
    remove_check_constraint :subscriptions, name: "subscriptions_lifecycle_shape"
    remove_check_constraint :subscriptions, name: "subscriptions_provider_metadata_bounded"
    remove_check_constraint :subscriptions, name: "subscriptions_provider_shape"
    remove_check_constraint :subscriptions, name: "subscriptions_access_state_allowlist"
    remove_check_constraint :subscriptions, name: "subscriptions_status_allowlist"
    remove_foreign_key :subscriptions, name: "fk_subscriptions_tenant_provider_customer"
    remove_index :subscriptions, name: "index_subscriptions_on_provider_identity"
    remove_index :subscriptions, name: "index_subscriptions_on_current_organization"

    %i[
      billing_customer_id provider provider_environment provider_subscription_id access_state
      provider_metadata current_period_starts_at current_period_ends_at trial_ends_at
      cancel_at_period_end canceled_at provider_updated_at last_synced_at
    ].each { |column| remove_column :subscriptions, column }

    add_index :subscriptions, :organization_id, unique: true,
      where: "status = 'active'", name: "index_subscriptions_on_active_organization"
    add_check_constraint :subscriptions,
      "status IN ('active', 'inactive')", name: "subscriptions_status_allowlist"
    add_check_constraint :subscriptions,
      "(status = 'active' AND ended_at IS NULL) OR (status = 'inactive' AND ended_at IS NOT NULL)",
      name: "subscriptions_lifecycle_shape"
  end

  def install_customer_mapping_guard
    execute <<~SQL
      CREATE FUNCTION enforce_billing_customer_mapping_immutability() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' OR
           NEW.organization_id IS DISTINCT FROM OLD.organization_id OR
           NEW.provider IS DISTINCT FROM OLD.provider OR
           NEW.environment IS DISTINCT FROM OLD.environment OR
           NEW.provider_customer_id IS DISTINCT FROM OLD.provider_customer_id THEN
          RAISE EXCEPTION 'billing customer mappings are immutable' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER billing_customers_immutable_mapping
      BEFORE UPDATE OR DELETE ON billing_customers
      FOR EACH ROW EXECUTE FUNCTION enforce_billing_customer_mapping_immutability();
    SQL
  end

  def provider_shape_sql
    <<~SQL.squish
      (billing_customer_id IS NULL AND provider IS NULL AND provider_environment IS NULL
        AND provider_subscription_id IS NULL AND provider_updated_at IS NULL AND last_synced_at IS NULL
        AND provider_metadata = '{}'::jsonb)
      OR
      (billing_customer_id IS NOT NULL AND provider IS NOT NULL AND provider_environment IS NOT NULL
        AND provider_subscription_id IS NOT NULL AND provider_updated_at IS NOT NULL AND last_synced_at IS NOT NULL
        AND provider_metadata ? 'raw_status')
    SQL
  end

  def lifecycle_shape_sql
    <<~SQL.squish
      (status = 'expired' AND ended_at IS NOT NULL)
      OR (status <> 'expired' AND ended_at IS NULL)
    SQL
  end

  def cancellation_shape_sql
    <<~SQL.squish
      ((cancel_at_period_end OR status = 'canceled') AND canceled_at IS NOT NULL)
      OR (status = 'expired' AND NOT cancel_at_period_end)
      OR (NOT cancel_at_period_end AND status NOT IN ('canceled', 'expired') AND canceled_at IS NULL)
    SQL
  end

  def period_shape_sql
    <<~SQL.squish
      (current_period_starts_at IS NULL AND current_period_ends_at IS NULL)
      OR (current_period_starts_at IS NOT NULL AND current_period_ends_at IS NOT NULL
        AND current_period_ends_at > current_period_starts_at)
    SQL
  end

  def status_access_shape_sql
    <<~SQL.squish
      (status = 'pending' AND access_state = 'pending')
      OR (status IN ('trialing', 'active') AND access_state = 'full')
      OR (status = 'past_due' AND access_state IN ('grace', 'read_only'))
      OR (status = 'paused' AND access_state IN ('read_only', 'suspended'))
      OR (status = 'canceled' AND access_state IN ('full', 'read_only'))
      OR (status = 'expired' AND access_state = 'read_only')
    SQL
  end
end
