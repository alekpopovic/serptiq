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

ActiveRecord::Schema[8.1].define(version: 2026_09_04_080000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "authentication_rate_limit_buckets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key_digest", limit: 64, null: false
    t.integer "request_count", null: false
    t.string "scope", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.datetime "window_started_at", null: false
    t.index ["expires_at"], name: "index_auth_rate_limits_on_expiry"
    t.index ["scope", "key_digest", "window_started_at"], name: "index_auth_rate_limits_on_scope_key_and_window", unique: true
    t.check_constraint "expires_at > window_started_at", name: "authentication_rate_limits_bounded_window"
    t.check_constraint "key_digest::text ~ '^[0-9a-f]{64}$'::text", name: "authentication_rate_limits_key_digest_format"
    t.check_constraint "request_count > 0", name: "authentication_rate_limits_positive_count"
    t.check_constraint "scope::text = ANY (ARRAY['oauth_start_ip'::character varying, 'oauth_link_session'::character varying, 'oauth_callback_failure_ip'::character varying, 'session_action_session'::character varying, 'account_security_session'::character varying]::text[])", name: "authentication_rate_limits_scope_allowlist"
  end

  create_table "authorization_catalog_revisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "checksum", limit: 64, null: false
    t.datetime "created_at", null: false
    t.integer "permission_count", null: false
    t.integer "role_count", null: false
    t.integer "schema_version", null: false
    t.string "source_path", limit: 255, null: false
    t.datetime "synced_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checksum"], name: "index_authorization_catalog_revisions_on_checksum", unique: true
    t.check_constraint "checksum::text ~ '^[0-9a-f]{64}$'::text", name: "authorization_catalog_revisions_checksum_format"
    t.check_constraint "permission_count > 0 AND role_count > 0", name: "authorization_catalog_revisions_positive_counts"
    t.check_constraint "schema_version > 0", name: "authorization_catalog_revisions_positive_schema"
    t.check_constraint "source_path::text = 'config_blueprints/permissions.yml'::text", name: "authorization_catalog_revisions_source_path"
  end

  create_table "authorization_scope_references", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "organization_id", null: false
    t.uuid "project_id"
    t.string "project_scope_type", limit: 24
    t.string "scope_type", limit: 24, null: false
    t.string "status", limit: 24, default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "id", "scope_type"], name: "index_authorization_scopes_on_org_id_and_type", unique: true
    t.index ["organization_id", "project_id"], name: "index_authorization_scopes_on_org_and_project"
    t.check_constraint "scope_type::text = 'Organization'::text AND id = organization_id AND project_id IS NULL AND project_scope_type IS NULL OR scope_type::text = 'Project'::text AND id <> organization_id AND project_id IS NULL AND project_scope_type IS NULL OR scope_type::text = 'Property'::text AND id <> organization_id AND project_id IS NOT NULL AND project_scope_type::text = 'Project'::text AND id <> project_id", name: "authorization_scopes_shape"
    t.check_constraint "scope_type::text = ANY (ARRAY['Organization'::character varying, 'Project'::character varying, 'Property'::character varying]::text[])", name: "authorization_scopes_type_allowlist"
    t.check_constraint "status::text = 'active'::text AND archived_at IS NULL OR status::text = 'archived'::text AND archived_at IS NOT NULL", name: "authorization_scopes_lifecycle"
  end

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

  create_table "invitation_rate_limit_buckets", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key_digest", limit: 64, null: false
    t.integer "request_count", null: false
    t.string "scope", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.datetime "window_started_at", null: false
    t.index ["expires_at"], name: "index_invitation_rate_limit_buckets_on_expires_at"
    t.index ["scope", "key_digest", "window_started_at"], name: "index_invitation_rate_limits_on_identity", unique: true
    t.check_constraint "expires_at > window_started_at", name: "invitation_rate_limits_bounded_window"
    t.check_constraint "key_digest::text ~ '^[0-9a-f]{64}$'::text", name: "invitation_rate_limits_key_digest_format"
    t.check_constraint "request_count > 0", name: "invitation_rate_limits_positive_count"
    t.check_constraint "scope::text = ANY (ARRAY['issue_actor'::character varying, 'issue_destination'::character varying, 'accept_ip'::character varying]::text[])", name: "invitation_rate_limits_scope_allowlist"
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.uuid "accepted_by_membership_id"
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.datetime "expired_at"
    t.datetime "expires_at", null: false
    t.string "initial_role_key", limit: 64
    t.uuid "initial_scope_id"
    t.string "initial_scope_type", limit: 32
    t.uuid "invited_by_membership_id", null: false
    t.uuid "organization_id", null: false
    t.datetime "revoked_at"
    t.string "status", limit: 24, default: "pending", null: false
    t.datetime "superseded_at"
    t.string "token_digest", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.index ["email", "status", "expires_at"], name: "index_invitations_on_email_status_and_expiry"
    t.index ["organization_id", "email"], name: "index_invitations_on_pending_org_and_email", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["organization_id", "status", "created_at"], name: "index_invitations_on_org_status_and_created"
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
    t.check_constraint "char_length(email::text) >= 3 AND char_length(email::text) <= 320 AND email::text = lower(btrim(email::text))", name: "invitations_email_format"
    t.check_constraint "expires_at > created_at AND expires_at <= (created_at + 'P30D'::interval)", name: "invitations_expiry_window"
    t.check_constraint "initial_role_key IS NULL AND initial_scope_type IS NULL AND initial_scope_id IS NULL OR (initial_role_key::text = ANY (ARRAY['organization_admin'::character varying, 'billing_admin'::character varying, 'seo_lead'::character varying, 'developer'::character varying, 'content_editor'::character varying, 'analyst'::character varying, 'viewer'::character varying]::text[])) AND initial_scope_type::text = 'Organization'::text AND initial_scope_id = organization_id", name: "invitations_initial_access_consistency"
    t.check_constraint "status::text = 'pending'::text AND accepted_at IS NULL AND accepted_by_membership_id IS NULL AND revoked_at IS NULL AND expired_at IS NULL AND superseded_at IS NULL OR status::text = 'accepted'::text AND accepted_at IS NOT NULL AND accepted_by_membership_id IS NOT NULL AND revoked_at IS NULL AND expired_at IS NULL AND superseded_at IS NULL OR status::text = 'revoked'::text AND revoked_at IS NOT NULL AND accepted_at IS NULL AND accepted_by_membership_id IS NULL AND expired_at IS NULL AND superseded_at IS NULL OR status::text = 'expired'::text AND expired_at IS NOT NULL AND accepted_at IS NULL AND accepted_by_membership_id IS NULL AND revoked_at IS NULL AND superseded_at IS NULL OR status::text = 'superseded'::text AND superseded_at IS NOT NULL AND accepted_at IS NULL AND accepted_by_membership_id IS NULL AND revoked_at IS NULL AND expired_at IS NULL", name: "invitations_lifecycle_consistency"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'revoked'::character varying, 'expired'::character varying, 'superseded'::character varying]::text[])", name: "invitations_status_allowlist"
    t.check_constraint "token_digest::text ~ '^[0-9a-f]{64}$'::text", name: "invitations_token_digest_format"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "display_name", limit: 160, null: false
    t.datetime "last_accessed_at"
    t.integer "lock_version", default: 0, null: false
    t.uuid "organization_id", null: false
    t.datetime "removed_at"
    t.string "status", limit: 32, default: "active", null: false
    t.datetime "suspended_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["organization_id", "id"], name: "index_memberships_on_organization_and_id", unique: true
    t.index ["organization_id", "status", "created_at"], name: "index_memberships_on_org_status_and_created"
    t.index ["organization_id", "user_id"], name: "index_memberships_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "status", "organization_id"], name: "index_memberships_on_user_status_and_org"
    t.check_constraint "char_length(display_name::text) >= 1 AND char_length(display_name::text) <= 160 AND display_name::text = btrim(display_name::text)", name: "memberships_display_name_format"
    t.check_constraint "status::text = 'invited'::text AND accepted_at IS NULL AND suspended_at IS NULL AND removed_at IS NULL OR status::text = 'active'::text AND accepted_at IS NOT NULL AND suspended_at IS NULL AND removed_at IS NULL OR status::text = 'suspended'::text AND accepted_at IS NOT NULL AND suspended_at IS NOT NULL AND removed_at IS NULL OR status::text = 'removed'::text AND suspended_at IS NULL AND removed_at IS NOT NULL", name: "memberships_lifecycle_consistency"
    t.check_constraint "status::text = ANY (ARRAY['invited'::character varying, 'active'::character varying, 'suspended'::character varying, 'removed'::character varying]::text[])", name: "memberships_status_allowlist"
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

  create_table "organization_ownerships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "assigned_at", null: false
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.uuid "membership_id", null: false
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["membership_id"], name: "index_organization_ownerships_on_active_membership", where: "(ended_at IS NULL)"
    t.index ["organization_id"], name: "index_organization_ownerships_on_active_org", unique: true, where: "(ended_at IS NULL)"
    t.index ["organization_id"], name: "index_organization_ownerships_on_organization_id"
    t.check_constraint "ended_at IS NULL OR ended_at >= assigned_at", name: "organization_ownerships_timestamp_order"
  end

  create_table "organization_slug_aliases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.citext "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "created_at"], name: "index_organization_slug_aliases_on_org_and_created"
    t.index ["organization_id"], name: "index_organization_slug_aliases_on_organization_id"
    t.index ["slug"], name: "index_organization_slug_aliases_on_slug", unique: true
    t.check_constraint "slug::text <> ALL (ARRAY['account'::text, 'billing'::text, 'invitations'::text, 'members'::text, 'new'::text, 'projects'::text, 'roles'::text, 'security'::text, 'settings'::text, 'switch'::text, 'teams'::text])", name: "organization_slug_aliases_not_reserved"
    t.check_constraint "slug::text ~ '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$'::text", name: "organization_slug_aliases_format"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "current_ownership_id", null: false
    t.string "data_region", limit: 32, default: "global", null: false
    t.string "default_locale", limit: 16, default: "en", null: false
    t.datetime "deleted_at"
    t.datetime "deletion_requested_at"
    t.integer "lock_version", default: 0, null: false
    t.string "name", limit: 160, null: false
    t.citext "slug", null: false
    t.string "status", limit: 32, default: "active", null: false
    t.datetime "suspended_at"
    t.string "time_zone", limit: 64, default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_active_slug", unique: true, where: "(deleted_at IS NULL)"
    t.check_constraint "char_length(name::text) >= 2 AND char_length(name::text) <= 160 AND name::text = btrim(name::text)", name: "organizations_name_format"
    t.check_constraint "data_region::text ~ '^[a-z][a-z0-9_-]{1,31}$'::text", name: "organizations_data_region_format"
    t.check_constraint "default_locale::text ~ '^[a-z]{2}(?:-[A-Z]{2})?$'::text", name: "organizations_locale_format"
    t.check_constraint "slug::text <> ALL (ARRAY['account'::text, 'billing'::text, 'invitations'::text, 'members'::text, 'new'::text, 'projects'::text, 'roles'::text, 'security'::text, 'settings'::text, 'switch'::text, 'teams'::text])", name: "organizations_slug_not_reserved"
    t.check_constraint "slug::text ~ '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$'::text", name: "organizations_slug_format"
    t.check_constraint "status::text = 'active'::text AND suspended_at IS NULL AND deletion_requested_at IS NULL AND deleted_at IS NULL OR status::text = 'suspended'::text AND suspended_at IS NOT NULL AND deletion_requested_at IS NULL AND deleted_at IS NULL OR status::text = 'pending_deletion'::text AND deletion_requested_at IS NOT NULL AND deleted_at IS NULL OR status::text = 'deleted'::text AND deletion_requested_at IS NOT NULL AND deleted_at IS NOT NULL AND deleted_at >= deletion_requested_at", name: "organizations_lifecycle_consistency"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying, 'pending_deletion'::character varying, 'deleted'::character varying]::text[])", name: "organizations_status_allowlist"
  end

  create_table "permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "catalog_checksum", limit: 64, null: false
    t.string "category", limit: 64, null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "key", limit: 128, null: false
    t.string "risk_level", limit: 16, null: false
    t.string "scope", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
    t.check_constraint "catalog_checksum::text ~ '^[0-9a-f]{64}$'::text", name: "permissions_catalog_checksum_format"
    t.check_constraint "char_length(category::text) >= 2 AND char_length(category::text) <= 64 AND category::text = btrim(category::text)", name: "permissions_category_format"
    t.check_constraint "char_length(description) >= 1 AND char_length(description) <= 500 AND description = btrim(description)", name: "permissions_description_format"
    t.check_constraint "key::text ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'::text", name: "permissions_key_format"
    t.check_constraint "risk_level::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'critical'::character varying]::text[])", name: "permissions_risk_allowlist"
    t.check_constraint "scope::text = ANY (ARRAY['organization'::character varying, 'project'::character varying]::text[])", name: "permissions_scope_allowlist"
  end

  create_table "role_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "effect", limit: 16, default: "allow", null: false
    t.datetime "expires_at"
    t.uuid "granted_by_membership_id", null: false
    t.uuid "grantee_id", null: false
    t.string "grantee_type", limit: 24, null: false
    t.uuid "membership_grantee_id"
    t.uuid "organization_id", null: false
    t.datetime "revoked_at"
    t.uuid "revoked_by_membership_id"
    t.uuid "role_id", null: false
    t.uuid "role_organization_id"
    t.boolean "role_system", null: false
    t.uuid "scope_id", null: false
    t.string "scope_type", limit: 24, null: false
    t.uuid "team_grantee_id"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "grantee_type", "grantee_id", "revoked_at", "expires_at"], name: "index_role_assignments_on_effective_principal"
    t.index ["organization_id", "grantee_type", "grantee_id", "role_id", "scope_type", "scope_id"], name: "index_role_assignments_on_active_grant", unique: true, where: "(revoked_at IS NULL)"
    t.index ["organization_id", "scope_type", "scope_id", "revoked_at", "expires_at"], name: "index_role_assignments_on_effective_scope"
    t.index ["role_id"], name: "index_role_assignments_on_role_id"
    t.check_constraint "effect::text = 'allow'::text", name: "role_assignments_allow_only"
    t.check_constraint "expires_at IS NULL OR expires_at > created_at", name: "role_assignments_expiry_after_creation"
    t.check_constraint "grantee_type::text = 'Membership'::text AND membership_grantee_id = grantee_id AND team_grantee_id IS NULL OR grantee_type::text = 'Team'::text AND team_grantee_id = grantee_id AND membership_grantee_id IS NULL", name: "role_assignments_grantee_shape"
    t.check_constraint "revoked_at IS NULL AND revoked_by_membership_id IS NULL OR revoked_at IS NOT NULL AND revoked_by_membership_id IS NOT NULL", name: "role_assignments_revocation_consistency"
    t.check_constraint "revoked_at IS NULL OR revoked_at >= created_at", name: "role_assignments_revocation_after_creation"
    t.check_constraint "role_system = true AND role_organization_id IS NULL OR role_system = false AND role_organization_id = organization_id", name: "role_assignments_role_tenant"
    t.check_constraint "scope_type::text = ANY (ARRAY['Organization'::character varying, 'Project'::character varying, 'Property'::character varying]::text[])", name: "role_assignments_scope_type_allowlist"
  end

  create_table "role_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "permission_id", null: false
    t.uuid "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "archived_at"
    t.string "assignable_scopes", default: [], null: false, array: true
    t.string "catalog_checksum", limit: 64
    t.datetime "created_at", null: false
    t.string "key", limit: 64, null: false
    t.boolean "mutable", default: true, null: false
    t.string "name", limit: 80, null: false
    t.uuid "organization_id"
    t.boolean "system", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["id", "system"], name: "index_roles_on_id_and_system", unique: true
    t.index ["key"], name: "index_roles_on_system_key", unique: true, where: "(system = true)"
    t.index ["organization_id", "id"], name: "index_roles_on_organization_and_id", unique: true
    t.index ["organization_id", "key"], name: "index_roles_on_organization_and_key", unique: true, where: "(system = false)"
    t.index ["organization_id"], name: "index_roles_on_organization_id"
    t.check_constraint "assignable_scopes = ARRAY['organization'::character varying] OR assignable_scopes = ARRAY['project'::character varying] OR assignable_scopes = ARRAY['organization'::character varying, 'project'::character varying]", name: "roles_assignable_scopes_allowlist"
    t.check_constraint "char_length(name::text) >= 2 AND char_length(name::text) <= 80 AND name::text = btrim(name::text)", name: "roles_name_format"
    t.check_constraint "key::text ~ '^[a-z][a-z0-9_]{1,63}$'::text", name: "roles_key_format"
    t.check_constraint "system = true AND organization_id IS NULL AND mutable = false AND archived_at IS NULL AND catalog_checksum::text ~ '^[0-9a-f]{64}$'::text AND (key::text = ANY (ARRAY['owner'::character varying, 'organization_admin'::character varying, 'billing_admin'::character varying, 'seo_lead'::character varying, 'developer'::character varying, 'content_editor'::character varying, 'analyst'::character varying, 'viewer'::character varying]::text[])) OR system = false AND organization_id IS NOT NULL AND mutable = true AND catalog_checksum IS NULL AND (key::text <> ALL (ARRAY['owner'::character varying, 'organization_admin'::character varying, 'billing_admin'::character varying, 'seo_lead'::character varying, 'developer'::character varying, 'content_editor'::character varying, 'analyst'::character varying, 'viewer'::character varying]::text[]))", name: "roles_ownership_consistency"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "authenticated_at", null: false
    t.string "client_name", limit: 32, default: "Unknown client", null: false
    t.datetime "created_at", null: false
    t.string "device_type", limit: 16, default: "Unknown", null: false
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
    t.index ["revoked_at"], name: "index_sessions_on_revoked_at", where: "(revoked_at IS NOT NULL)"
    t.index ["rotated_from_id"], name: "index_sessions_on_rotated_from_id"
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id", "expires_at"], name: "index_sessions_on_user_id_and_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
    t.check_constraint "authenticated_at <= last_seen_at", name: "sessions_authentication_before_last_seen"
    t.check_constraint "client_name::text = ANY (ARRAY['Chrome'::character varying, 'Edge'::character varying, 'Firefox'::character varying, 'Safari'::character varying, 'Other client'::character varying, 'Unknown client'::character varying]::text[])", name: "sessions_client_name_allowlist"
    t.check_constraint "device_type::text = ANY (ARRAY['Desktop'::character varying, 'Mobile'::character varying, 'Tablet'::character varying, 'Unknown'::character varying]::text[])", name: "sessions_device_type_allowlist"
    t.check_constraint "expires_at > last_seen_at", name: "sessions_expiry_after_last_seen"
    t.check_constraint "ip_address_digest IS NULL OR ip_address_digest::text ~ '^[0-9a-f]{64}$'::text", name: "sessions_ip_digest_format"
    t.check_constraint "revoke_reason IS NULL OR (revoke_reason::text = ANY (ARRAY['logout'::character varying, 'rotated'::character varying, 'privilege_changed'::character varying, 'user_inactive'::character varying, 'administrative'::character varying]::text[]))", name: "sessions_revoke_reason_allowlist"
    t.check_constraint "revoked_at IS NULL AND revoke_reason IS NULL OR revoked_at IS NOT NULL AND revoke_reason IS NOT NULL", name: "sessions_revocation_consistency"
    t.check_constraint "token_digest::text ~ '^[0-9a-f]{64}$'::text", name: "sessions_token_digest_format"
    t.check_constraint "user_agent_digest IS NULL OR user_agent_digest::text ~ '^[0-9a-f]{64}$'::text", name: "sessions_user_agent_digest_format"
  end

  create_table "team_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "added_at", null: false
    t.uuid "added_by_membership_id", null: false
    t.datetime "created_at", null: false
    t.uuid "membership_id", null: false
    t.uuid "organization_id", null: false
    t.datetime "removed_at"
    t.uuid "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "membership_id", "removed_at"], name: "index_team_memberships_on_org_member_and_removed"
    t.index ["organization_id", "team_id", "added_at"], name: "index_team_memberships_on_org_team_and_added"
    t.index ["team_id", "membership_id"], name: "index_team_memberships_on_active_team_and_member", unique: true, where: "(removed_at IS NULL)"
    t.check_constraint "removed_at IS NULL OR removed_at >= added_at", name: "team_memberships_timestamp_order"
  end

  create_table "teams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.citext "name", null: false
    t.uuid "organization_id", null: false
    t.string "status", limit: 24, default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "id"], name: "index_teams_on_organization_and_id", unique: true
    t.index ["organization_id", "name"], name: "index_teams_on_active_organization_and_name", unique: true, where: "(archived_at IS NULL)"
    t.index ["organization_id", "status", "created_at"], name: "index_teams_on_org_status_and_created"
    t.index ["organization_id"], name: "index_teams_on_organization_id"
    t.check_constraint "char_length(name::text) >= 2 AND char_length(name::text) <= 120 AND name::text = btrim(name::text)", name: "teams_name_format"
    t.check_constraint "status::text = 'active'::text AND archived_at IS NULL OR status::text = 'archived'::text AND archived_at IS NOT NULL", name: "teams_lifecycle_consistency"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "teams_status_allowlist"
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

  add_foreign_key "authorization_scope_references", "authorization_scope_references", column: ["organization_id", "project_id", "project_scope_type"], primary_key: ["organization_id", "id", "scope_type"], name: "fk_authorization_property_scope_same_org_project", on_delete: :restrict
  add_foreign_key "authorization_scope_references", "organizations", on_delete: :restrict
  add_foreign_key "identities", "users", on_delete: :restrict
  add_foreign_key "invitations", "memberships", column: ["organization_id", "accepted_by_membership_id"], primary_key: ["organization_id", "id"], name: "fk_invitations_same_org_acceptor", on_delete: :restrict
  add_foreign_key "invitations", "memberships", column: ["organization_id", "invited_by_membership_id"], primary_key: ["organization_id", "id"], name: "fk_invitations_same_org_inviter", on_delete: :restrict
  add_foreign_key "invitations", "organizations", on_delete: :restrict
  add_foreign_key "memberships", "organizations", on_delete: :restrict
  add_foreign_key "memberships", "users", on_delete: :restrict
  add_foreign_key "oauth_transactions", "sessions", column: "link_session_id", on_delete: :restrict
  add_foreign_key "organization_ownerships", "memberships", column: ["organization_id", "membership_id"], primary_key: ["organization_id", "id"], name: "fk_ownerships_same_organization_membership", on_delete: :restrict
  add_foreign_key "organization_ownerships", "organizations", on_delete: :restrict
  add_foreign_key "organization_slug_aliases", "organizations", on_delete: :restrict
  add_foreign_key "organizations", "organization_ownerships", column: "current_ownership_id", on_delete: :restrict, deferrable: :deferred
  add_foreign_key "role_assignments", "authorization_scope_references", column: ["organization_id", "scope_id", "scope_type"], primary_key: ["organization_id", "id", "scope_type"], name: "fk_role_assignments_same_org_scope", on_delete: :restrict
  add_foreign_key "role_assignments", "memberships", column: ["organization_id", "granted_by_membership_id"], primary_key: ["organization_id", "id"], name: "fk_role_assignments_same_org_grantor", on_delete: :restrict
  add_foreign_key "role_assignments", "memberships", column: ["organization_id", "membership_grantee_id"], primary_key: ["organization_id", "id"], name: "fk_role_assignments_same_org_membership", on_delete: :restrict
  add_foreign_key "role_assignments", "memberships", column: ["organization_id", "revoked_by_membership_id"], primary_key: ["organization_id", "id"], name: "fk_role_assignments_same_org_revoker", on_delete: :restrict
  add_foreign_key "role_assignments", "organizations", on_delete: :restrict
  add_foreign_key "role_assignments", "roles", column: ["role_id", "role_system"], primary_key: ["id", "system"], name: "fk_role_assignments_role_kind", on_delete: :restrict
  add_foreign_key "role_assignments", "roles", column: ["role_organization_id", "role_id"], primary_key: ["organization_id", "id"], name: "fk_role_assignments_same_org_custom_role", on_delete: :restrict
  add_foreign_key "role_assignments", "teams", column: ["organization_id", "team_grantee_id"], primary_key: ["organization_id", "id"], name: "fk_role_assignments_same_org_team", on_delete: :restrict
  add_foreign_key "role_permissions", "permissions", on_delete: :restrict
  add_foreign_key "role_permissions", "roles", on_delete: :restrict
  add_foreign_key "roles", "organizations", on_delete: :restrict
  add_foreign_key "sessions", "sessions", column: "rotated_from_id", on_delete: :restrict
  add_foreign_key "sessions", "users", on_delete: :restrict
  add_foreign_key "team_memberships", "memberships", column: ["organization_id", "added_by_membership_id"], primary_key: ["organization_id", "id"], name: "fk_team_memberships_same_org_actor", on_delete: :restrict
  add_foreign_key "team_memberships", "memberships", column: ["organization_id", "membership_id"], primary_key: ["organization_id", "id"], name: "fk_team_memberships_same_org_member", on_delete: :restrict
  add_foreign_key "team_memberships", "organizations", on_delete: :restrict
  add_foreign_key "team_memberships", "teams", column: ["organization_id", "team_id"], primary_key: ["organization_id", "id"], name: "fk_team_memberships_same_org_team", on_delete: :restrict
  add_foreign_key "teams", "organizations", on_delete: :restrict
end
