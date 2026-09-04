# frozen_string_literal: true

class CreateSecureOrganizationInvitations < ActiveRecord::Migration[8.1]
  ROLE_KEYS = %w[organization_admin billing_admin seo_lead developer content_editor analyst viewer].freeze

  def change
    create_table :invitations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
      t.uuid :invited_by_membership_id, null: false
      t.citext :email, null: false
      t.string :token_digest, limit: 64, null: false
      t.string :status, limit: 24, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.uuid :accepted_by_membership_id
      t.datetime :revoked_at
      t.datetime :expired_at
      t.datetime :superseded_at
      t.string :initial_role_key, limit: 64
      t.string :initial_scope_type, limit: 32
      t.uuid :initial_scope_id

      t.timestamps
    end
    add_foreign_key :invitations, :memberships,
      column: %i[organization_id invited_by_membership_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_invitations_same_org_inviter"
    add_foreign_key :invitations, :memberships,
      column: %i[organization_id accepted_by_membership_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_invitations_same_org_acceptor"
    add_index :invitations, :token_digest, unique: true
    add_index :invitations, %i[organization_id email], unique: true, where: "status = 'pending'",
      name: "index_invitations_on_pending_org_and_email"
    add_index :invitations, %i[email status expires_at], name: "index_invitations_on_email_status_and_expiry"
    add_index :invitations, %i[organization_id status created_at],
      name: "index_invitations_on_org_status_and_created"
    add_check_constraint :invitations, "token_digest ~ '^[0-9a-f]{64}$'", name: "invitations_token_digest_format"
    add_check_constraint :invitations,
      "char_length(email) BETWEEN 3 AND 320 AND email = lower(btrim(email))",
      name: "invitations_email_format"
    add_check_constraint :invitations, "expires_at > created_at AND expires_at <= created_at + interval '30 days'",
      name: "invitations_expiry_window"
    add_check_constraint :invitations,
      "status IN ('pending', 'accepted', 'revoked', 'expired', 'superseded')",
      name: "invitations_status_allowlist"
    add_check_constraint :invitations, invitation_lifecycle_constraint,
      name: "invitations_lifecycle_consistency"
    add_check_constraint :invitations, initial_access_constraint,
      name: "invitations_initial_access_consistency"

    create_table :invitation_rate_limit_buckets, id: false do |t|
      t.string :scope, limit: 32, null: false
      t.string :key_digest, limit: 64, null: false
      t.datetime :window_started_at, null: false
      t.datetime :expires_at, null: false
      t.integer :request_count, null: false

      t.timestamps
    end
    add_index :invitation_rate_limit_buckets, %i[scope key_digest window_started_at], unique: true,
      name: "index_invitation_rate_limits_on_identity"
    add_index :invitation_rate_limit_buckets, :expires_at
    add_check_constraint :invitation_rate_limit_buckets,
      "scope IN ('issue_actor', 'issue_destination', 'accept_ip')",
      name: "invitation_rate_limits_scope_allowlist"
    add_check_constraint :invitation_rate_limit_buckets, "key_digest ~ '^[0-9a-f]{64}$'",
      name: "invitation_rate_limits_key_digest_format"
    add_check_constraint :invitation_rate_limit_buckets, "request_count > 0",
      name: "invitation_rate_limits_positive_count"
    add_check_constraint :invitation_rate_limit_buckets, "expires_at > window_started_at",
      name: "invitation_rate_limits_bounded_window"
  end

  private

  def invitation_lifecycle_constraint
    <<~SQL.squish
      (status = 'pending' AND accepted_at IS NULL AND accepted_by_membership_id IS NULL
        AND revoked_at IS NULL AND expired_at IS NULL AND superseded_at IS NULL)
      OR (status = 'accepted' AND accepted_at IS NOT NULL AND accepted_by_membership_id IS NOT NULL
        AND revoked_at IS NULL AND expired_at IS NULL AND superseded_at IS NULL)
      OR (status = 'revoked' AND revoked_at IS NOT NULL AND accepted_at IS NULL
        AND accepted_by_membership_id IS NULL AND expired_at IS NULL AND superseded_at IS NULL)
      OR (status = 'expired' AND expired_at IS NOT NULL AND accepted_at IS NULL
        AND accepted_by_membership_id IS NULL AND revoked_at IS NULL AND superseded_at IS NULL)
      OR (status = 'superseded' AND superseded_at IS NOT NULL AND accepted_at IS NULL
        AND accepted_by_membership_id IS NULL AND revoked_at IS NULL AND expired_at IS NULL)
    SQL
  end

  def initial_access_constraint
    roles = ROLE_KEYS.map { |key| connection.quote(key) }.join(", ")
    <<~SQL.squish
      (initial_role_key IS NULL AND initial_scope_type IS NULL AND initial_scope_id IS NULL)
      OR (initial_role_key IN (#{roles}) AND initial_scope_type = 'Organization'
        AND initial_scope_id = organization_id)
    SQL
  end
end
