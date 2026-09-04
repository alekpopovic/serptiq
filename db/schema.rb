# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_04_033000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address_digest", limit: 64
    t.datetime "last_seen_at", null: false
    t.string "revoke_reason", limit: 64
    t.datetime "revoked_at"
    t.uuid "rotated_from_id"
    t.string "token_digest", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.string "user_agent_digest", limit: 64
    t.uuid "user_id", null: false
    t.index ["expires_at"], name: "index_sessions_on_active_expiry", where: "(revoked_at IS NULL)"
    t.index ["rotated_from_id"], name: "index_sessions_on_rotated_from_id"
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id", "expires_at"], name: "index_sessions_on_user_id_and_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
    t.check_constraint "expires_at > last_seen_at", name: "sessions_expiry_after_last_seen"
    t.check_constraint "ip_address_digest IS NULL OR ip_address_digest::text ~ '^[0-9a-f]{64}$'::text", name: "sessions_ip_digest_format"
    t.check_constraint "revoked_at IS NULL AND revoke_reason IS NULL OR revoked_at IS NOT NULL AND revoke_reason IS NOT NULL", name: "sessions_revocation_consistency"
    t.check_constraint "token_digest::text ~ '^[0-9a-f]{64}$'::text", name: "sessions_token_digest_format"
    t.check_constraint "user_agent_digest IS NULL OR user_agent_digest::text ~ '^[0-9a-f]{64}$'::text", name: "sessions_user_agent_digest_format"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_terms_at"
    t.text "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "display_name"
    t.string "locale", default: "en", null: false
    t.string "primary_email"
    t.datetime "suspended_at"
    t.string "time_zone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index "lower((primary_email)::text)", name: "index_users_on_active_normalized_email", unique: true, where: "((primary_email IS NOT NULL) AND (deleted_at IS NULL))"
    t.check_constraint "char_length(locale::text) >= 2 AND char_length(locale::text) <= 16", name: "users_locale_length"
    t.check_constraint "char_length(time_zone::text) >= 1 AND char_length(time_zone::text) <= 64", name: "users_time_zone_length"
    t.check_constraint "primary_email IS NULL OR char_length(primary_email::text) >= 3 AND char_length(primary_email::text) <= 320 AND primary_email::text = lower(primary_email::text)", name: "users_normalized_email"
  end

  add_foreign_key "sessions", "sessions", column: "rotated_from_id", on_delete: :restrict
  add_foreign_key "sessions", "users", on_delete: :restrict
end
