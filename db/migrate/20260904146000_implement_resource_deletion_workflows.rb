# frozen_string_literal: true

class ImplementResourceDeletionWorkflows < ActiveRecord::Migration[8.1]
  STAGES = %w[
    cancel_active_work integrations scans_and_findings reports object_artifacts
    api_keys_and_webhooks aggregate_records
  ].freeze

  def up
    create_workflows
    create_stage_executions
    create_audit_target_tombstones
    extend_resource_lifecycles
    install_deletion_authorization
    protect_retained_history
  end

  def down
    restore_retained_history_guards
    remove_deletion_authorization
    restore_resource_lifecycles
    drop_table :audit_target_tombstones
    drop_table :resource_deletion_stage_executions
    drop_table :resource_deletion_workflows
  end

  private

  def create_workflows
    create_table :resource_deletion_workflows, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.string :target_type, limit: 24, null: false
      t.uuid :target_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id
      t.uuid :requested_by_membership_id, null: false
      t.string :state, limit: 24, null: false, default: "holding"
      t.string :current_stage, limit: 32
      t.datetime :requested_at, null: false
      t.datetime :hold_until, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :canceled_at
      t.datetime :next_attempt_at
      t.string :last_error_category, limit: 64
      t.uuid :lease_token
      t.datetime :lease_expires_at
      t.integer :attempt_count, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :resource_deletion_workflows, :organizations, on_delete: :restrict
    add_foreign_key :resource_deletion_workflows, :memberships,
      column: %i[organization_id requested_by_membership_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_deletion_workflows_tenant_requester"
    add_index :resource_deletion_workflows, %i[organization_id id], unique: true,
      name: "index_deletion_workflows_on_tenant_identity"
    add_index :resource_deletion_workflows,
      %i[organization_id id target_type target_id], unique: true,
      name: "index_deletion_workflows_on_exact_target_identity"
    add_index :resource_deletion_workflows,
      %i[organization_id target_type target_id], unique: true,
      where: "state IN ('holding', 'running', 'retryable')",
      name: "index_deletion_workflows_on_active_target"
    add_index :resource_deletion_workflows, %i[state hold_until next_attempt_at],
      name: "index_deletion_workflows_on_due_work"

    add_check_constraint :resource_deletion_workflows,
      "target_type IN ('Project', 'Property') AND " \
        "((target_type = 'Project' AND target_id = project_id AND property_id IS NULL) OR " \
        "(target_type = 'Property' AND target_id = property_id AND property_id IS NOT NULL))",
      name: "deletion_workflows_target_shape"
    add_check_constraint :resource_deletion_workflows,
      "hold_until > requested_at AND attempt_count >= 0",
      name: "deletion_workflows_time_and_attempts"
    add_check_constraint :resource_deletion_workflows,
      "current_stage IS NULL OR current_stage IN (#{quoted_stages})",
      name: "deletion_workflows_stage_allowlist"
    add_check_constraint :resource_deletion_workflows,
      "last_error_category IS NULL OR last_error_category ~ '^[a-z][a-z0-9_]{0,63}$'",
      name: "deletion_workflows_error_category"
    add_check_constraint :resource_deletion_workflows, workflow_state_constraint,
      name: "deletion_workflows_state_shape"
  end

  def create_stage_executions
    create_table :resource_deletion_stage_executions, id: :uuid,
      default: -> { "gen_random_uuid()" } do |t|
      t.uuid :resource_deletion_workflow_id, null: false
      t.uuid :organization_id, null: false
      t.string :stage, limit: 32, null: false
      t.integer :position, null: false
      t.string :state, limit: 24, null: false, default: "pending"
      t.integer :attempt_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.string :last_error_category, limit: 64
      t.string :cursor, limit: 512
      t.timestamps
    end

    add_foreign_key :resource_deletion_stage_executions, :resource_deletion_workflows,
      column: %i[organization_id resource_deletion_workflow_id],
      primary_key: %i[organization_id id], on_delete: :cascade,
      name: "fk_deletion_stages_tenant_workflow"
    add_index :resource_deletion_stage_executions,
      %i[resource_deletion_workflow_id position], unique: true,
      name: "index_deletion_stages_on_workflow_position"
    add_index :resource_deletion_stage_executions,
      %i[resource_deletion_workflow_id stage], unique: true,
      name: "index_deletion_stages_on_workflow_stage"
    add_check_constraint :resource_deletion_stage_executions,
      STAGES.each_with_index.map { |stage, index| "(stage = '#{stage}' AND position = #{index})" }.join(" OR "),
      name: "deletion_stages_ordered_allowlist"
    add_check_constraint :resource_deletion_stage_executions,
      "state IN ('pending', 'running', 'retryable', 'completed') AND attempt_count >= 0",
      name: "deletion_stages_state_and_attempts"
    add_check_constraint :resource_deletion_stage_executions,
      "last_error_category IS NULL OR last_error_category ~ '^[a-z][a-z0-9_]{0,63}$'",
      name: "deletion_stages_error_category"
  end

  def create_audit_target_tombstones
    create_table :audit_target_tombstones, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :deletion_workflow_id, null: false
      t.string :target_type, limit: 48, null: false
      t.uuid :target_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id
      t.datetime :deleted_at, null: false
      t.datetime :created_at, null: false
    end

    add_foreign_key :audit_target_tombstones, :organizations, on_delete: :restrict
    add_foreign_key :audit_target_tombstones, :resource_deletion_workflows,
      column: %i[organization_id deletion_workflow_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_audit_tombstones_tenant_workflow"
    add_index :audit_target_tombstones, %i[organization_id target_type target_id], unique: true,
      name: "index_audit_tombstones_on_target"
    add_index :audit_target_tombstones, %i[organization_id project_id property_id],
      name: "index_audit_tombstones_on_resource_hierarchy"
    add_check_constraint :audit_target_tombstones,
      "target_type IN ('Project', 'Property', 'PropertyEnvironment', 'DomainVerification', 'CrawlPolicy')",
      name: "audit_tombstones_target_type"
  end

  def extend_resource_lifecycles
    add_column :projects, :work_cancellation_cutoff_at, :datetime
    add_column :projects, :deletion_workflow_id, :uuid
    add_column :properties, :deletion_requested_at, :datetime
    add_column :properties, :work_cancellation_cutoff_at, :datetime
    add_column :properties, :deletion_workflow_id, :uuid

    add_foreign_key :projects, :resource_deletion_workflows,
      column: %i[organization_id deletion_workflow_id authorization_scope_type id],
      primary_key: %i[organization_id id target_type target_id], on_delete: :restrict,
      name: "fk_projects_exact_deletion_workflow"
    add_foreign_key :properties, :resource_deletion_workflows,
      column: %i[organization_id deletion_workflow_id authorization_scope_type id],
      primary_key: %i[organization_id id target_type target_id], on_delete: :restrict,
      name: "fk_properties_exact_deletion_workflow"

    remove_check_constraint :projects, name: "projects_lifecycle_consistency"
    add_check_constraint :projects, project_lifecycle_constraint,
      name: "projects_lifecycle_consistency"
    remove_check_constraint :properties, name: "properties_lifecycle_consistency"
    add_check_constraint :properties, property_lifecycle_constraint,
      name: "properties_lifecycle_consistency"
    add_index :projects, :deletion_workflow_id, unique: true,
      where: "deletion_workflow_id IS NOT NULL"
    add_index :properties, :deletion_workflow_id, unique: true,
      where: "deletion_workflow_id IS NOT NULL"
  end

  def install_deletion_authorization
    execute <<~SQL
      CREATE FUNCTION resource_deletion_stage_authorized(
        target_organization_id uuid,
        target_project_id uuid,
        target_property_id uuid,
        required_stage text
      ) RETURNS boolean AS $$
      DECLARE
        workflow_setting text;
      BEGIN
        workflow_setting := current_setting('searchops.deletion_workflow_id', TRUE);
        IF workflow_setting IS NULL OR workflow_setting !~
          '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
          RETURN FALSE;
        END IF;

        RETURN EXISTS (
          SELECT 1 FROM resource_deletion_workflows workflows
          WHERE workflows.id = workflow_setting::uuid
            AND workflows.organization_id = target_organization_id
            AND workflows.project_id = target_project_id
            AND (workflows.target_type = 'Project'
              OR (workflows.target_type = 'Property' AND workflows.property_id = target_property_id))
            AND workflows.state = 'running'
            AND workflows.current_stage = required_stage
            AND workflows.hold_until <= CURRENT_TIMESTAMP
            AND workflows.lease_expires_at > CURRENT_TIMESTAMP
        );
      END;
      $$ LANGUAGE plpgsql STABLE;
    SQL

    execute <<~SQL
      CREATE FUNCTION protect_project_lifecycle_deletion() RETURNS trigger AS $$
      BEGIN
        IF NOT resource_deletion_stage_authorized(
          OLD.organization_id, OLD.id, NULL, 'aggregate_records'
        ) THEN
          RAISE EXCEPTION 'project deletion requires an active lifecycle workflow';
        END IF;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER projects_require_deletion_workflow
      BEFORE DELETE ON projects FOR EACH ROW EXECUTE FUNCTION protect_project_lifecycle_deletion();

      CREATE FUNCTION protect_property_lifecycle_deletion() RETURNS trigger AS $$
      BEGIN
        IF NOT resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.id, 'aggregate_records'
        ) THEN
          RAISE EXCEPTION 'property deletion requires an active lifecycle workflow';
        END IF;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER properties_require_deletion_workflow
      BEFORE DELETE ON properties FOR EACH ROW EXECUTE FUNCTION protect_property_lifecycle_deletion();
    SQL
  end

  def protect_retained_history
    execute <<~SQL
      CREATE FUNCTION prevent_audit_target_tombstone_mutation() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'audit target tombstones are append-only';
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER audit_target_tombstones_immutable
      BEFORE UPDATE OR DELETE ON audit_target_tombstones
      FOR EACH ROW EXECUTE FUNCTION prevent_audit_target_tombstone_mutation();

      CREATE OR REPLACE FUNCTION prevent_domain_verification_attempt_mutation() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'aggregate_records'
        ) THEN
          RETURN OLD;
        END IF;
        RAISE EXCEPTION 'domain verification attempts are append-only';
      END;
      $$ LANGUAGE plpgsql;

      CREATE FUNCTION protect_domain_verification_deletion() RETURNS trigger AS $$
      BEGIN
        IF NOT resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'aggregate_records'
        ) THEN
          RAISE EXCEPTION 'domain verification deletion requires an active lifecycle workflow';
        END IF;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER domain_verifications_require_deletion_workflow
      BEFORE DELETE ON domain_verifications
      FOR EACH ROW EXECUTE FUNCTION protect_domain_verification_deletion();

      CREATE OR REPLACE FUNCTION reject_crawl_policy_immutable_change() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN
          RETURN OLD;
        END IF;
        RAISE EXCEPTION '% rows are immutable', TG_TABLE_NAME;
      END;
      $$ LANGUAGE plpgsql;

      CREATE FUNCTION protect_crawl_policy_set_deletion() RETURNS trigger AS $$
      BEGIN
        IF NOT resource_deletion_stage_authorized(
          OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
        ) THEN
          RAISE EXCEPTION 'crawl policy deletion requires an active lifecycle workflow';
        END IF;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER crawl_policy_sets_require_deletion_workflow
      BEFORE DELETE ON crawl_policy_sets
      FOR EACH ROW EXECUTE FUNCTION protect_crawl_policy_set_deletion();
    SQL
  end

  def restore_retained_history_guards
    execute <<~SQL
      DROP TRIGGER IF EXISTS crawl_policy_sets_require_deletion_workflow ON crawl_policy_sets;
      DROP FUNCTION IF EXISTS protect_crawl_policy_set_deletion();
      CREATE OR REPLACE FUNCTION reject_crawl_policy_immutable_change() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION '% rows are immutable', TG_TABLE_NAME;
      END;
      $$ LANGUAGE plpgsql;

      DROP TRIGGER IF EXISTS domain_verifications_require_deletion_workflow ON domain_verifications;
      DROP FUNCTION IF EXISTS protect_domain_verification_deletion();
      CREATE OR REPLACE FUNCTION prevent_domain_verification_attempt_mutation() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'domain verification attempts are append-only';
      END;
      $$ LANGUAGE plpgsql;

      DROP TRIGGER IF EXISTS audit_target_tombstones_immutable ON audit_target_tombstones;
      DROP FUNCTION IF EXISTS prevent_audit_target_tombstone_mutation();
    SQL
  end

  def remove_deletion_authorization
    execute <<~SQL
      DROP TRIGGER IF EXISTS properties_require_deletion_workflow ON properties;
      DROP FUNCTION IF EXISTS protect_property_lifecycle_deletion();
      DROP TRIGGER IF EXISTS projects_require_deletion_workflow ON projects;
      DROP FUNCTION IF EXISTS protect_project_lifecycle_deletion();
      DROP FUNCTION IF EXISTS resource_deletion_stage_authorized(uuid, uuid, uuid, text);
    SQL
  end

  def restore_resource_lifecycles
    remove_foreign_key :properties, name: "fk_properties_exact_deletion_workflow"
    remove_foreign_key :projects, name: "fk_projects_exact_deletion_workflow"
    remove_check_constraint :properties, name: "properties_lifecycle_consistency"
    add_check_constraint :properties,
      "(status = 'active' AND archived_at IS NULL) OR " \
        "(status = 'archived' AND archived_at IS NOT NULL)",
      name: "properties_lifecycle_consistency"
    remove_check_constraint :projects, name: "projects_lifecycle_consistency"
    add_check_constraint :projects,
      "(status = 'active' AND archived_at IS NULL AND deletion_requested_at IS NULL) OR " \
        "(status = 'archived' AND archived_at IS NOT NULL AND deletion_requested_at IS NULL) OR " \
        "(status = 'pending_deletion' AND archived_at IS NOT NULL AND deletion_requested_at IS NOT NULL " \
        "AND deletion_requested_at >= archived_at)",
      name: "projects_lifecycle_consistency"
    remove_column :properties, :deletion_workflow_id
    remove_column :properties, :work_cancellation_cutoff_at
    remove_column :properties, :deletion_requested_at
    remove_column :projects, :deletion_workflow_id
    remove_column :projects, :work_cancellation_cutoff_at
  end

  def quoted_stages
    STAGES.map { |stage| connection.quote(stage) }.join(", ")
  end

  def workflow_state_constraint
    <<~SQL.squish
      (state = 'holding' AND current_stage IS NULL AND started_at IS NULL AND completed_at IS NULL
        AND canceled_at IS NULL AND next_attempt_at IS NULL AND last_error_category IS NULL
        AND lease_token IS NULL AND lease_expires_at IS NULL)
      OR (state = 'running' AND current_stage IS NOT NULL AND started_at IS NOT NULL
        AND completed_at IS NULL AND canceled_at IS NULL AND next_attempt_at IS NULL
        AND last_error_category IS NULL AND lease_token IS NOT NULL AND lease_expires_at IS NOT NULL)
      OR (state = 'retryable' AND current_stage IS NOT NULL AND started_at IS NOT NULL
        AND completed_at IS NULL AND canceled_at IS NULL AND next_attempt_at IS NOT NULL
        AND last_error_category IS NOT NULL AND lease_token IS NULL AND lease_expires_at IS NULL)
      OR (state = 'completed' AND current_stage = 'aggregate_records' AND started_at IS NOT NULL
        AND completed_at IS NOT NULL AND canceled_at IS NULL AND next_attempt_at IS NULL
        AND last_error_category IS NULL AND lease_token IS NULL AND lease_expires_at IS NULL)
      OR (state = 'canceled' AND current_stage IS NULL AND started_at IS NULL AND completed_at IS NULL
        AND canceled_at IS NOT NULL AND next_attempt_at IS NULL AND last_error_category IS NULL
        AND lease_token IS NULL AND lease_expires_at IS NULL)
    SQL
  end

  def project_lifecycle_constraint
    <<~SQL.squish
      (status = 'active' AND archived_at IS NULL AND deletion_requested_at IS NULL
        AND deletion_workflow_id IS NULL)
      OR (status = 'archived' AND archived_at IS NOT NULL AND deletion_requested_at IS NULL
        AND deletion_workflow_id IS NULL)
      OR (status = 'pending_deletion' AND archived_at IS NOT NULL AND deletion_requested_at IS NOT NULL
        AND deletion_workflow_id IS NOT NULL AND deletion_requested_at >= archived_at)
    SQL
  end

  def property_lifecycle_constraint
    <<~SQL.squish
      (status = 'active' AND archived_at IS NULL AND deletion_requested_at IS NULL
        AND deletion_workflow_id IS NULL)
      OR (status = 'archived' AND archived_at IS NOT NULL AND deletion_requested_at IS NULL
        AND deletion_workflow_id IS NULL)
      OR (status = 'pending_deletion' AND archived_at IS NOT NULL AND deletion_requested_at IS NOT NULL
        AND deletion_workflow_id IS NOT NULL AND deletion_requested_at >= archived_at)
    SQL
  end
end
