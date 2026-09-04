# frozen_string_literal: true

class BindOauthInitiationsToSafeDimensions < ActiveRecord::Migration[8.1]
  LEGACY_INITIATOR_DIGEST = "0" * 64

  def up
    add_column :sessions, :authenticated_at, :datetime
    execute "UPDATE sessions SET authenticated_at = LEAST(created_at, last_seen_at)"
    change_column_null :sessions, :authenticated_at, false
    add_check_constraint :sessions,
      "authenticated_at <= last_seen_at",
      name: "sessions_authentication_before_last_seen"

    add_column :oauth_transactions, :initiator_digest, :string,
      limit: 64, null: false, default: LEGACY_INITIATOR_DIGEST
    change_column_default :oauth_transactions, :initiator_digest, from: LEGACY_INITIATOR_DIGEST, to: nil
    add_column :oauth_transactions, :link_intent, :boolean, null: false, default: false
    add_reference :oauth_transactions, :link_session, type: :uuid, index: false,
      foreign_key: { to_table: :sessions, on_delete: :restrict }

    add_index :oauth_transactions, [ :initiator_digest, :created_at ],
      name: "index_oauth_transactions_on_initiator_and_created"
    add_index :oauth_transactions, [ :initiator_digest, :expires_at ],
      where: "consumed_at IS NULL", name: "index_oauth_transactions_on_open_initiator"
    add_index :oauth_transactions, [ :link_session_id, :created_at ],
      where: "link_intent", name: "index_oauth_transactions_on_link_session"
    add_check_constraint :oauth_transactions,
      "initiator_digest ~ '^[0-9a-f]{64}$'",
      name: "oauth_transactions_initiator_digest_format"
    add_check_constraint :oauth_transactions,
      "(NOT link_intent AND link_session_id IS NULL) OR (link_intent AND link_session_id IS NOT NULL)",
      name: "oauth_transactions_link_binding"
  end

  def down
    remove_check_constraint :oauth_transactions, name: "oauth_transactions_link_binding"
    remove_check_constraint :oauth_transactions, name: "oauth_transactions_initiator_digest_format"
    remove_index :oauth_transactions, name: "index_oauth_transactions_on_link_session"
    remove_index :oauth_transactions, name: "index_oauth_transactions_on_open_initiator"
    remove_index :oauth_transactions, name: "index_oauth_transactions_on_initiator_and_created"
    remove_reference :oauth_transactions, :link_session, foreign_key: { to_table: :sessions }
    remove_column :oauth_transactions, :link_intent
    remove_column :oauth_transactions, :initiator_digest
    remove_check_constraint :sessions, name: "sessions_authentication_before_last_seen"
    remove_column :sessions, :authenticated_at
  end
end
