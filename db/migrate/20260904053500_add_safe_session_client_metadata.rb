# frozen_string_literal: true

class AddSafeSessionClientMetadata < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  CLIENT_NAMES = [ "Chrome", "Edge", "Firefox", "Safari", "Other client", "Unknown client" ].freeze
  DEVICE_TYPES = [ "Desktop", "Mobile", "Tablet", "Unknown" ].freeze

  def up
    add_column :sessions, :client_name, :string, limit: 32, null: false, default: "Unknown client" unless
      column_exists?(:sessions, :client_name)
    add_column :sessions, :device_type, :string, limit: 16, null: false, default: "Unknown" unless
      column_exists?(:sessions, :device_type)
    unless check_constraint_exists?(:sessions, name: "sessions_client_name_allowlist")
      add_check_constraint :sessions,
        "client_name IN (#{quoted(CLIENT_NAMES)})",
        name: "sessions_client_name_allowlist",
        validate: false
    end
    unless check_constraint_exists?(:sessions, name: "sessions_device_type_allowlist")
      add_check_constraint :sessions,
        "device_type IN (#{quoted(DEVICE_TYPES)})",
        name: "sessions_device_type_allowlist",
        validate: false
    end
    validate_check_constraint :sessions, name: "sessions_client_name_allowlist"
    validate_check_constraint :sessions, name: "sessions_device_type_allowlist"
    unless index_exists?(:sessions, :revoked_at, name: "index_sessions_on_revoked_at")
      add_index :sessions, :revoked_at,
        where: "revoked_at IS NOT NULL",
        name: "index_sessions_on_revoked_at",
        algorithm: :concurrently
    end
  end

  def down
    remove_index :sessions, name: "index_sessions_on_revoked_at", algorithm: :concurrently, if_exists: true
    remove_check_constraint :sessions, name: "sessions_device_type_allowlist", if_exists: true
    remove_check_constraint :sessions, name: "sessions_client_name_allowlist", if_exists: true
    remove_column :sessions, :device_type, if_exists: true
    remove_column :sessions, :client_name, if_exists: true
  end

  private

  def quoted(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
