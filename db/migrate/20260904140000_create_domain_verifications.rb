# frozen_string_literal: true

class CreateDomainVerifications < ActiveRecord::Migration[8.1]
  def up
    add_index :property_environments, %i[organization_id project_id property_id id], unique: true,
      name: "index_property_environments_on_tenant_identity"

    create_table :domain_verifications, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :issued_by_membership_id, null: false
      t.string :method, limit: 32, null: false
      t.string :challenge_digest, limit: 64, null: false
      t.text :expected_location, null: false
      t.text :bound_origin, null: false
      t.string :state, limit: 24, null: false, default: "pending"
      t.integer :attempt_count, null: false, default: 0
      t.datetime :attempted_at
      t.datetime :verified_at
      t.datetime :failed_at
      t.datetime :expired_at
      t.datetime :revoked_at
      t.datetime :expires_at, null: false
      t.string :failure_category, limit: 48
      t.jsonb :evidence, null: false, default: {}
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :domain_verifications, :property_environments,
      column: %i[organization_id project_id property_id environment_id],
      primary_key: %i[organization_id project_id property_id id],
      on_delete: :restrict,
      name: "fk_domain_verifications_tenant_environment"
    add_foreign_key :domain_verifications, :memberships,
      column: %i[organization_id issued_by_membership_id],
      primary_key: %i[organization_id id],
      on_delete: :restrict,
      name: "fk_domain_verifications_tenant_issuer"
    add_index :domain_verifications,
      %i[organization_id project_id property_id environment_id id], unique: true,
      name: "index_domain_verifications_on_tenant_identity"
    add_index :domain_verifications,
      %i[organization_id project_id property_id environment_id state created_at],
      name: "index_domain_verifications_on_environment_state"
    add_index :domain_verifications, %i[organization_id environment_id], unique: true,
      where: "state IN ('pending', 'verified')",
      name: "index_domain_verifications_on_current_environment"
    add_index :domain_verifications, :challenge_digest, unique: true

    add_check_constraint :domain_verifications,
      "method IN ('dns_txt', 'html_file', 'meta_tag', 'search_console')",
      name: "domain_verifications_method_allowlist"
    add_check_constraint :domain_verifications,
      "challenge_digest ~ '^[0-9a-f]{64}$'",
      name: "domain_verifications_digest_format"
    add_check_constraint :domain_verifications,
      "char_length(expected_location) BETWEEN 1 AND 2048 AND " \
        "char_length(bound_origin) BETWEEN 8 AND 2048",
      name: "domain_verifications_bounded_binding"
    add_check_constraint :domain_verifications,
      "state IN ('pending', 'verified', 'failed', 'expired', 'revoked')",
      name: "domain_verifications_state_allowlist"
    add_check_constraint :domain_verifications,
      "attempt_count >= 0 AND ((attempt_count = 0 AND attempted_at IS NULL) OR " \
        "(attempt_count > 0 AND attempted_at IS NOT NULL))",
      name: "domain_verifications_attempt_shape"
    add_check_constraint :domain_verifications,
      verification_lifecycle_check,
      name: "domain_verifications_lifecycle"
    add_check_constraint :domain_verifications,
      "jsonb_typeof(evidence) = 'object' AND octet_length(evidence::text) <= 4096",
      name: "domain_verifications_evidence_shape"
    add_check_constraint :domain_verifications,
      "expires_at > created_at",
      name: "domain_verifications_expiry_order"

    create_table :domain_verification_attempts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :domain_verification_id, null: false
      t.integer :sequence, null: false
      t.string :outcome, limit: 24, null: false
      t.string :failure_category, limit: 48
      t.jsonb :evidence, null: false, default: {}
      t.datetime :attempted_at, null: false
      t.datetime :created_at, null: false
    end

    add_foreign_key :domain_verification_attempts, :domain_verifications,
      column: %i[organization_id project_id property_id environment_id domain_verification_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict,
      name: "fk_verification_attempts_tenant_challenge"
    add_index :domain_verification_attempts, %i[domain_verification_id sequence], unique: true,
      name: "index_verification_attempts_on_sequence"
    add_index :domain_verification_attempts,
      %i[organization_id project_id property_id environment_id attempted_at],
      name: "index_verification_attempts_on_environment"
    add_check_constraint :domain_verification_attempts,
      "sequence > 0 AND outcome IN ('verified', 'failed')",
      name: "domain_verification_attempts_outcome"
    add_check_constraint :domain_verification_attempts,
      "(outcome = 'verified' AND failure_category IS NULL) OR " \
        "(outcome = 'failed' AND failure_category IS NOT NULL)",
      name: "domain_verification_attempts_failure_shape"
    add_check_constraint :domain_verification_attempts,
      "jsonb_typeof(evidence) = 'object' AND octet_length(evidence::text) <= 4096",
      name: "domain_verification_attempts_evidence_shape"

    protect_verification_history
    protect_verification_binding
    validate_verification_origin_binding
    invalidate_origin_bound_verifications
  end

  def down
    execute "DROP TRIGGER IF EXISTS property_environments_invalidate_verifications ON property_environments"
    execute "DROP FUNCTION IF EXISTS invalidate_origin_bound_verifications()"
    execute "DROP TRIGGER IF EXISTS domain_verifications_validate_origin ON domain_verifications"
    execute "DROP FUNCTION IF EXISTS validate_domain_verification_origin()"
    execute "DROP TRIGGER IF EXISTS domain_verifications_protect_binding ON domain_verifications"
    execute "DROP FUNCTION IF EXISTS protect_domain_verification_binding()"
    execute "DROP TRIGGER IF EXISTS domain_verification_attempts_immutable ON domain_verification_attempts"
    execute "DROP FUNCTION IF EXISTS prevent_domain_verification_attempt_mutation()"
    drop_table :domain_verification_attempts
    drop_table :domain_verifications
    remove_index :property_environments, name: "index_property_environments_on_tenant_identity"
  end

  private

  def verification_lifecycle_check
    <<~SQL.squish
      (state = 'pending' AND verified_at IS NULL AND failed_at IS NULL
        AND expired_at IS NULL AND revoked_at IS NULL AND failure_category IS NULL)
      OR (state = 'verified' AND verified_at IS NOT NULL AND failed_at IS NULL
        AND expired_at IS NULL AND revoked_at IS NULL AND failure_category IS NULL)
      OR (state = 'failed' AND verified_at IS NULL AND failed_at IS NOT NULL
        AND expired_at IS NULL AND revoked_at IS NULL AND failure_category IS NOT NULL)
      OR (state = 'expired' AND failed_at IS NULL AND expired_at IS NOT NULL
        AND revoked_at IS NULL AND failure_category IS NULL)
      OR (state = 'revoked' AND failed_at IS NULL AND expired_at IS NULL
        AND revoked_at IS NOT NULL AND failure_category IS NULL)
    SQL
  end

  def protect_verification_history
    execute <<~SQL
      CREATE FUNCTION prevent_domain_verification_attempt_mutation() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'domain verification attempts are append-only';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER domain_verification_attempts_immutable
      BEFORE UPDATE OR DELETE ON domain_verification_attempts
      FOR EACH ROW EXECUTE FUNCTION prevent_domain_verification_attempt_mutation();
    SQL
  end

  def protect_verification_binding
    execute <<~SQL
      CREATE FUNCTION protect_domain_verification_binding() RETURNS trigger AS $$
      BEGIN
        IF NEW.id IS DISTINCT FROM OLD.id
          OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.issued_by_membership_id IS DISTINCT FROM OLD.issued_by_membership_id
          OR NEW.method IS DISTINCT FROM OLD.method
          OR NEW.challenge_digest IS DISTINCT FROM OLD.challenge_digest
          OR NEW.expected_location IS DISTINCT FROM OLD.expected_location
          OR NEW.bound_origin IS DISTINCT FROM OLD.bound_origin
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'domain verification binding cannot be changed';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER domain_verifications_protect_binding
      BEFORE UPDATE ON domain_verifications
      FOR EACH ROW EXECUTE FUNCTION protect_domain_verification_binding();
    SQL
  end

  def invalidate_origin_bound_verifications
    execute <<~SQL
      CREATE FUNCTION invalidate_origin_bound_verifications() RETURNS trigger AS $$
      BEGIN
        IF NEW.origin IS DISTINCT FROM OLD.origin THEN
          UPDATE domain_verifications
          SET state = 'revoked', revoked_at = CURRENT_TIMESTAMP,
            failed_at = NULL, expired_at = NULL, failure_category = NULL,
            lock_version = lock_version + 1, updated_at = CURRENT_TIMESTAMP
          WHERE organization_id = NEW.organization_id
            AND project_id = NEW.project_id
            AND property_id = NEW.property_id
            AND environment_id = NEW.id
            AND bound_origin IS DISTINCT FROM NEW.origin
            AND state IN ('pending', 'verified');

          UPDATE properties
          SET verification_status = 'unverified', verified_at = NULL,
            lock_version = lock_version + 1, updated_at = CURRENT_TIMESTAMP
          WHERE organization_id = NEW.organization_id
            AND project_id = NEW.project_id
            AND id = NEW.property_id
            AND NEW."primary" = TRUE;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER property_environments_invalidate_verifications
      AFTER UPDATE OF origin ON property_environments
      FOR EACH ROW EXECUTE FUNCTION invalidate_origin_bound_verifications();
    SQL
  end

  def validate_verification_origin_binding
    execute <<~SQL
      CREATE FUNCTION validate_domain_verification_origin() RETURNS trigger AS $$
      BEGIN
        PERFORM 1 FROM property_environments
        WHERE organization_id = NEW.organization_id
          AND project_id = NEW.project_id
          AND property_id = NEW.property_id
          AND id = NEW.environment_id
          AND status = 'active'
          AND origin = NEW.bound_origin
        FOR KEY SHARE;
        IF NOT FOUND THEN
          RAISE EXCEPTION 'domain verification origin does not match active environment';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER domain_verifications_validate_origin
      BEFORE INSERT ON domain_verifications
      FOR EACH ROW EXECUTE FUNCTION validate_domain_verification_origin();
    SQL
  end
end
