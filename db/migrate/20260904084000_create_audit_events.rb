# frozen_string_literal: true

class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id
      t.string :actor_type, limit: 24, null: false
      t.uuid :actor_membership_id
      t.uuid :actor_user_id
      t.string :action, limit: 96, null: false
      t.string :target_type, limit: 48, null: false
      t.uuid :target_id
      t.string :result, limit: 24, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :request_id, limit: 128
      t.string :trace_id, limit: 128
      t.string :job_id, limit: 128
      t.string :source_ip_digest, limit: 64
      t.string :user_agent_digest, limit: 64
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
    end

    add_foreign_key :audit_events, :organizations, on_delete: :restrict
    add_foreign_key :audit_events, :memberships,
      column: %i[organization_id actor_membership_id],
      primary_key: %i[organization_id id],
      on_delete: :restrict,
      name: "fk_audit_events_same_org_actor"
    add_foreign_key :audit_events, :users, column: :actor_user_id, on_delete: :restrict

    add_index :audit_events, %i[organization_id occurred_at id],
      order: { occurred_at: :desc, id: :desc }, name: "index_audit_events_on_org_timeline"
    add_index :audit_events, %i[organization_id action occurred_at],
      order: { occurred_at: :desc }, name: "index_audit_events_on_org_action"
    add_index :audit_events, %i[organization_id target_type target_id occurred_at],
      order: { occurred_at: :desc }, name: "index_audit_events_on_org_target"
    add_index :audit_events, %i[organization_id actor_membership_id occurred_at],
      order: { occurred_at: :desc }, name: "index_audit_events_on_org_actor"
    add_index :audit_events, :request_id, where: "request_id IS NOT NULL"
    add_index :audit_events, :job_id, where: "job_id IS NOT NULL"

    add_check_constraint :audit_events, actor_shape_sql, name: "audit_events_actor_shape"
    add_check_constraint :audit_events,
      "action ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'",
      name: "audit_events_action_format"
    add_check_constraint :audit_events,
      "target_type ~ '^[A-Z][A-Za-z0-9]{0,47}$'",
      name: "audit_events_target_type_format"
    add_check_constraint :audit_events,
      "result IN ('succeeded', 'denied', 'failed', 'ignored')",
      name: "audit_events_result_allowlist"
    add_check_constraint :audit_events,
      "jsonb_typeof(metadata) = 'object' AND pg_column_size(metadata) <= 8192",
      name: "audit_events_metadata_bounded"
    add_check_constraint :audit_events,
      digest_shape_sql,
      name: "audit_events_client_digest_shape"
  end

  private

  def actor_shape_sql
    <<~SQL.squish
      (actor_type = 'Membership' AND organization_id IS NOT NULL
        AND actor_membership_id IS NOT NULL AND actor_user_id IS NULL)
      OR (actor_type = 'User' AND actor_membership_id IS NULL AND actor_user_id IS NOT NULL)
      OR (actor_type = 'System' AND actor_membership_id IS NULL AND actor_user_id IS NULL)
    SQL
  end

  def digest_shape_sql
    <<~SQL.squish
      (source_ip_digest IS NULL OR source_ip_digest ~ '^[0-9a-f]{64}$')
      AND (user_agent_digest IS NULL OR user_agent_digest ~ '^[0-9a-f]{64}$')
    SQL
  end
end
