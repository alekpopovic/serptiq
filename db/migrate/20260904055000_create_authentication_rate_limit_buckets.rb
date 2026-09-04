# frozen_string_literal: true

class CreateAuthenticationRateLimitBuckets < ActiveRecord::Migration[8.1]
  SCOPES = %w[
    oauth_start_ip
    oauth_link_session
    oauth_callback_failure_ip
    session_action_session
    account_security_session
  ].freeze

  def change
    create_table :authentication_rate_limit_buckets do |t|
      t.string :scope, limit: 64, null: false
      t.string :key_digest, limit: 64, null: false
      t.datetime :window_started_at, null: false
      t.datetime :expires_at, null: false
      t.integer :request_count, null: false

      t.timestamps
    end

    add_index :authentication_rate_limit_buckets,
      %i[scope key_digest window_started_at],
      unique: true,
      name: "index_auth_rate_limits_on_scope_key_and_window"
    add_index :authentication_rate_limit_buckets, :expires_at,
      name: "index_auth_rate_limits_on_expiry"
    add_check_constraint :authentication_rate_limit_buckets,
      "scope IN (#{SCOPES.map { |scope| connection.quote(scope) }.join(', ')})",
      name: "authentication_rate_limits_scope_allowlist"
    add_check_constraint :authentication_rate_limit_buckets,
      "key_digest ~ '^[0-9a-f]{64}$'",
      name: "authentication_rate_limits_key_digest_format"
    add_check_constraint :authentication_rate_limit_buckets,
      "request_count > 0",
      name: "authentication_rate_limits_positive_count"
    add_check_constraint :authentication_rate_limit_buckets,
      "expires_at > window_started_at",
      name: "authentication_rate_limits_bounded_window"
  end
end
