# frozen_string_literal: true

class CreateNativeSessionFoundations < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid, default: -> { "gen_random_uuid()" } do |table|
      table.string :primary_email
      table.string :display_name
      table.text :avatar_url
      table.string :locale, null: false, default: "en"
      table.string :time_zone, null: false, default: "UTC"
      table.datetime :accepted_terms_at
      table.datetime :suspended_at
      table.datetime :deleted_at
      table.timestamps
    end

    add_index :users, "lower(primary_email)", unique: true,
      where: "primary_email IS NOT NULL AND deleted_at IS NULL",
      name: "index_users_on_active_normalized_email"
    add_check_constraint :users,
      "primary_email IS NULL OR (char_length(primary_email) BETWEEN 3 AND 320 AND primary_email = lower(primary_email))",
      name: "users_normalized_email"
    add_check_constraint :users, "char_length(locale) BETWEEN 2 AND 16", name: "users_locale_length"
    add_check_constraint :users, "char_length(time_zone) BETWEEN 1 AND 64", name: "users_time_zone_length"

    create_table :sessions, id: :uuid, default: -> { "gen_random_uuid()" } do |table|
      table.references :user, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
      table.string :token_digest, null: false, limit: 64
      table.string :ip_address_digest, limit: 64
      table.string :user_agent_digest, limit: 64
      table.datetime :last_seen_at, null: false
      table.datetime :expires_at, null: false
      table.datetime :revoked_at
      table.string :revoke_reason, limit: 64
      table.references :rotated_from, type: :uuid, foreign_key: { to_table: :sessions, on_delete: :restrict }
      table.timestamps
    end

    add_index :sessions, :token_digest, unique: true
    add_index :sessions, [ :user_id, :expires_at ]
    add_index :sessions, :expires_at, where: "revoked_at IS NULL", name: "index_sessions_on_active_expiry"
    add_check_constraint :sessions, "token_digest ~ '^[0-9a-f]{64}$'", name: "sessions_token_digest_format"
    add_check_constraint :sessions,
      "ip_address_digest IS NULL OR ip_address_digest ~ '^[0-9a-f]{64}$'",
      name: "sessions_ip_digest_format"
    add_check_constraint :sessions,
      "user_agent_digest IS NULL OR user_agent_digest ~ '^[0-9a-f]{64}$'",
      name: "sessions_user_agent_digest_format"
    add_check_constraint :sessions, "expires_at > last_seen_at", name: "sessions_expiry_after_last_seen"
    add_check_constraint :sessions,
      "(revoked_at IS NULL AND revoke_reason IS NULL) OR (revoked_at IS NOT NULL AND revoke_reason IS NOT NULL)",
      name: "sessions_revocation_consistency"
  end
end
