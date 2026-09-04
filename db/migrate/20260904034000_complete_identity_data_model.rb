# frozen_string_literal: true

class CompleteIdentityDataModel < ActiveRecord::Migration[8.1]
  PROVIDERS = %w[google github].freeze

  def up
    enable_extension "citext" unless extension_enabled?("citext")
    change_column :users, :primary_email, :citext

    create_table :identities, id: :uuid, default: -> { "gen_random_uuid()" } do |table|
      table.references :user, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
      table.string :provider, null: false, limit: 32
      table.string :provider_subject, null: false, limit: 255
      table.citext :email
      table.boolean :email_verified, null: false, default: false
      table.jsonb :profile, null: false, default: {}
      table.datetime :last_authenticated_at, null: false
      table.datetime :revoked_at
      table.timestamps
    end

    add_index :identities, [ :provider, :provider_subject ], unique: true
    add_index :identities, [ :user_id, :provider ]
    add_index :identities, :email
    add_check_constraint :identities, provider_check("provider"), name: "identities_provider_allowlist"
    add_check_constraint :identities,
      "char_length(provider_subject) BETWEEN 1 AND 255 AND provider_subject = btrim(provider_subject)",
      name: "identities_subject_format"
    add_check_constraint :identities,
      "email IS NULL OR (char_length(email::text) BETWEEN 3 AND 320 AND email::text = lower(email::text))",
      name: "identities_normalized_email"
    add_check_constraint :identities, "NOT email_verified OR email IS NOT NULL",
      name: "identities_verified_email_present"
    add_check_constraint :identities,
      "jsonb_typeof(profile) = 'object' AND octet_length(profile::text) <= 8192",
      name: "identities_profile_object"
    add_check_constraint :identities,
      "profile - 'name' - 'login' - 'avatar_url' - 'locale' = '{}'::jsonb",
      name: "identities_profile_keys"

    create_table :oauth_transactions, id: :uuid, default: -> { "gen_random_uuid()" } do |table|
      table.string :provider, null: false, limit: 32
      table.string :state_digest, null: false, limit: 64
      table.string :nonce_digest, limit: 64
      table.string :pkce_verifier_digest, null: false, limit: 64
      table.text :pkce_verifier_ciphertext, null: false
      table.text :return_to, null: false, default: "/dashboard"
      table.datetime :expires_at, null: false
      table.datetime :consumed_at
      table.integer :attempt_count, null: false, default: 0
      table.datetime :last_attempted_at
      table.timestamps
    end

    add_index :oauth_transactions, :state_digest, unique: true
    add_index :oauth_transactions, :nonce_digest, unique: true, where: "nonce_digest IS NOT NULL"
    add_index :oauth_transactions, :pkce_verifier_digest, unique: true
    add_index :oauth_transactions, :expires_at, where: "consumed_at IS NULL",
      name: "index_oauth_transactions_on_open_expiry"
    add_check_constraint :oauth_transactions, provider_check("provider"), name: "oauth_transactions_provider_allowlist"
    add_check_constraint :oauth_transactions, digest_check("state_digest"), name: "oauth_transactions_state_digest_format"
    add_check_constraint :oauth_transactions,
      "nonce_digest IS NULL OR #{digest_check('nonce_digest')}",
      name: "oauth_transactions_nonce_digest_format"
    add_check_constraint :oauth_transactions,
      "provider <> 'google' OR nonce_digest IS NOT NULL",
      name: "oauth_transactions_google_nonce_required"
    add_check_constraint :oauth_transactions, digest_check("pkce_verifier_digest"),
      name: "oauth_transactions_pkce_digest_format"
    add_check_constraint :oauth_transactions,
      "char_length(pkce_verifier_ciphertext) BETWEEN 32 AND 4096",
      name: "oauth_transactions_pkce_ciphertext_length"
    add_check_constraint :oauth_transactions,
      "return_to ~ '^/dashboard(?:/[A-Za-z0-9_-]+)*$' AND char_length(return_to) <= 2048",
      name: "oauth_transactions_safe_return_path"
    add_check_constraint :oauth_transactions,
      "expires_at > created_at AND expires_at <= created_at + INTERVAL '15 minutes'",
      name: "oauth_transactions_bounded_expiry"
    add_check_constraint :oauth_transactions, "attempt_count >= 0",
      name: "oauth_transactions_attempt_count_nonnegative"
    add_check_constraint :oauth_transactions,
      "(attempt_count = 0 AND last_attempted_at IS NULL) OR (attempt_count > 0 AND last_attempted_at IS NOT NULL)",
      name: "oauth_transactions_attempt_metadata"
    add_check_constraint :oauth_transactions,
      "consumed_at IS NULL OR (last_attempted_at IS NOT NULL AND consumed_at <= last_attempted_at)",
      name: "oauth_transactions_consumption_metadata"

    add_check_constraint :sessions,
      "revoke_reason IS NULL OR revoke_reason IN ('logout', 'rotated', 'privilege_changed', 'user_inactive', 'administrative')",
      name: "sessions_revoke_reason_allowlist"
  end

  def down
    remove_check_constraint :sessions, name: "sessions_revoke_reason_allowlist"
    drop_table :oauth_transactions
    drop_table :identities
    change_column :users, :primary_email, :string
    disable_extension "citext" if extension_enabled?("citext")
  end

  private

  def provider_check(column)
    "#{column} IN (#{PROVIDERS.map { |provider| connection.quote(provider) }.join(', ')})"
  end

  def digest_check(column)
    "#{column} ~ '^[0-9a-f]{64}$'"
  end
end
