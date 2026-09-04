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

ActiveRecord::Schema[8.1].define(version: 2026_09_04_051500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "identities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.citext "email"
    t.boolean "email_verified", default: false, null: false
    t.datetime "last_authenticated_at", null: false
    t.jsonb "profile", default: {}, null: false
    t.string "provider", limit: 32, null: false
    t.string "provider_subject", limit: 255, null: false
    t.datetime "revoked_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["email"], name: "index_identities_on_email"
    t.index ["provider", "provider_subject"], name: "index_identities_on_provider_and_provider_subject", unique: true
    t.index ["user_id", "provider"], name: "index_identities_on_active_user_and_provider", unique: true, where: "(revoked_at IS NULL)"
    t.index ["user_id", "provider"], name: "index_identities_on_user_id_and_provider"
    t.index ["user_id"], name: "index_identities_on_user_id"
    t.check_constraint "(profile - 'name'::text - 'login'::text - 'avatar_url'::text - 'locale'::text) = '{}'::jsonb", name: "identities_profile_keys"
    t.check_constraint "NOT email_verified OR email IS NOT NULL", name: "identities_verified_email_present"
    t.check_constraint "char_length(provider_subject::text) >= 1 AND char_length(provider_subject::text) <= 255 AND provider_subject::text = btrim(provider_subject::text)", name: "identities_subject_format"
    t.check_constraint "email IS NULL OR char_length(email::text) >= 3 AND char_length(email::text) <= 320 AND email::text = lower(email::text)", name: "identities_normalized_email"
    t.check_constraint "jsonb_typeof(profile) = 'object'::text AND octet_length(profile::text) <= 8192", name: "identities_profile_object"
    t.check_constraint "provider::text = ANY (ARRAY['google'::character varying, 'github'::character varying]::text[])", name: "identities_provider_allowlist"
    t.check_constraint "revoked_at IS NULL OR revoked_at >= created_at", name: "identities_revocation_follows_creation"
  end

  create_table "oauth_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "initiator_digest", limit: 64, null: false
    t.datetime "last_attempted_at"
    t.boolean "link_intent", default: false, null: false
    t.uuid "link_session_id"
    t.string "nonce_digest", limit: 64
    t.text "pkce_verifier_ciphertext", null: false
    t.string "pkce_verifier_digest", limit: 64, null: false
    t.string "provider", limit: 32, null: false
    t.text "return_to", default: "/dashboard", null: false
    t.string "state_digest", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_oauth_transactions_on_open_expiry", where: "(consumed_at IS NULL)"
    t.index ["initiator_digest", "created_at"], name: "index_oauth_transactions_on_initiator_and_created"
    t.index ["initiator_digest", "expires_at"], name: "index_oauth_transactions_on_open_initiator", where: "(consumed_at IS NULL)"
    t.index ["link_session_id", "created_at"], name: "index_oauth_transactions_on_link_session", where: "link_intent"
    t.index ["nonce_digest"], name: "index_oauth_transactions_on_nonce_digest", unique: true, where: "(nonce_digest IS NOT NULL)"
    t.index ["pkce_verifier_digest"], name: "index_oauth_transactions_on_pkce_verifier_digest", unique: true
    t.index ["state_digest"], name: "index_oauth_transactions_on_state_digest", unique: true
    t.check_constraint "NOT link_intent AND link_session_id IS NULL OR link_intent AND link_session_id IS NOT NULL", name: "oauth_transactions_link_binding"
    t.check_constraint "attempt_count = 0 AND last_attempted_at IS NULL OR attempt_count > 0 AND last_attempted_at IS NOT NULL", name: "oauth_transactions_attempt_metadata"
    t.check_constraint "attempt_count >= 0", name: "oauth_transactions_attempt_count_nonnegative"
    t.check_constraint "char_length(pkce_verifier_ciphertext) >= 32 AND char_length(pkce_verifier_ciphertext) <= 4096", name: "oauth_transactions_pkce_ciphertext_length"
    t.check_constraint "consumed_at IS NULL OR last_attempted_at IS NOT NULL AND consumed_at <= last_attempted_at", name: "oauth_transactions_consumption_metadata"
    t.check_constraint "expires_at > created_at AND expires_at <= (created_at + 'PT15M'::interval)", name: "oauth_transactions_bounded_expiry"
    t.check_constraint "initiator_digest::text ~ '^[0-9a-f]{64}$'::text", name: "oauth_transactions_initiator_digest_format"
    t.check_constraint "nonce_digest IS NULL OR nonce_digest::text ~ '^[0-9a-f]{64}$'::text", name: "oauth_transactions_nonce_digest_format"
    t.check_constraint "pkce_verifier_digest::text ~ '^[0-9a-f]{64}$'::text", name: "oauth_transactions_pkce_digest_format"
    t.check_constraint "provider::text <> 'google'::text OR nonce_digest IS NOT NULL", name: "oauth_transactions_google_nonce_required"
    t.check_constraint "provider::text = ANY (ARRAY['google'::character varying, 'github'::character varying]::text[])", name: "oauth_transactions_provider_allowlist"
    t.check_constraint "return_to ~ '^/dashboard(?:/[A-Za-z0-9_-]+)*$'::text AND char_length(return_to) <= 2048", name: "oauth_transactions_safe_return_path"
    t.check_constraint "state_digest::text ~ '^[0-9a-f]{64}$'::text", name: "oauth_transactions_state_digest_format"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "authenticated_at", null: false
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
    t.check_constraint "authenticated_at <= last_seen_at", name: "sessions_authentication_before_last_seen"
    t.check_constraint "expires_at > last_seen_at", name: "sessions_expiry_after_last_seen"
    t.check_constraint "ip_address_digest IS NULL OR ip_address_digest::text ~ '^[0-9a-f]{64}$'::text", name: "sessions_ip_digest_format"
    t.check_constraint "revoke_reason IS NULL OR (revoke_reason::text = ANY (ARRAY['logout'::character varying, 'rotated'::character varying, 'privilege_changed'::character varying, 'user_inactive'::character varying, 'administrative'::character varying]::text[]))", name: "sessions_revoke_reason_allowlist"
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
    t.citext "primary_email"
    t.datetime "suspended_at"
    t.string "time_zone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index "lower((primary_email)::text)", name: "index_users_on_active_normalized_email", unique: true, where: "((primary_email IS NOT NULL) AND (deleted_at IS NULL))"
    t.check_constraint "char_length(locale::text) >= 2 AND char_length(locale::text) <= 16", name: "users_locale_length"
    t.check_constraint "char_length(time_zone::text) >= 1 AND char_length(time_zone::text) <= 64", name: "users_time_zone_length"
    t.check_constraint "primary_email IS NULL OR char_length(primary_email::text) >= 3 AND char_length(primary_email::text) <= 320 AND primary_email::text = lower(primary_email::text)", name: "users_normalized_email"
  end

  add_foreign_key "identities", "users", on_delete: :restrict
  add_foreign_key "oauth_transactions", "sessions", column: "link_session_id", on_delete: :restrict
  add_foreign_key "sessions", "sessions", column: "rotated_from_id", on_delete: :restrict
  add_foreign_key "sessions", "users", on_delete: :restrict
end
