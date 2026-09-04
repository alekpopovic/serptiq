# frozen_string_literal: true

class AddSearchConsoleVerification < ActiveRecord::Migration[8.1]
  EXISTING_FAILURE_CATEGORIES = %w[
    proof_missing proof_mismatch provider_unavailable provider_unauthorized unsafe_destination
    malformed_response attempt_limit dns_nxdomain dns_no_record dns_propagating dns_timeout
    dns_transient_failure dns_multiple_records dns_response_limit dns_cname_limit dns_delegation_limit
    http_dns_failure http_timeout http_transport_failure http_redirect_rejected http_redirect_limit
    http_response_too_large http_content_type_rejected duplicate_meta
  ].freeze
  SEARCH_CONSOLE_FAILURE_CATEGORIES = %w[
    provider_scope_revoked provider_property_inaccessible provider_outage provider_ambiguous_match
    provider_no_match provider_insufficient_permission provider_connection_changed
  ].freeze
  FAILURE_CONSTRAINTS = {
    domain_verifications: "domain_verifications_failure_category_allowlist",
    domain_verification_attempts: "domain_verification_attempts_failure_category_allowlist"
  }.freeze

  def up
    create_connections
    add_selection_binding
    replace_failure_constraints(EXISTING_FAILURE_CATEGORIES + SEARCH_CONSOLE_FAILURE_CATEGORIES)
    protect_selection_binding
    invalidate_connection_bound_verifications
  end

  def down
    execute "DROP TRIGGER IF EXISTS integration_connections_invalidate_verifications ON integration_connections"
    execute "DROP FUNCTION IF EXISTS invalidate_connection_bound_verifications()"
    restore_original_binding_protection
    replace_failure_constraints(EXISTING_FAILURE_CATEGORIES)
    remove_foreign_key :domain_verifications, name: "fk_domain_verifications_tenant_integration"
    remove_index :domain_verifications, name: "index_domain_verifications_on_integration"
    remove_check_constraint :domain_verifications, name: "domain_verifications_search_console_binding"
    remove_columns :domain_verifications,
      :integration_connection_id, :provider_property_identifier, :provider_property_type,
      :provider_permission_level, :provider_checked_at, :connection_revision
    drop_table :integration_connections
  end

  private

  def create_connections
    create_table :integration_connections, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :connected_by_membership_id, null: false
      t.string :provider, limit: 32, null: false
      t.string :external_account_id, limit: 255, null: false
      t.string :consent_kind, limit: 48, null: false
      t.string :consent_digest, limit: 64, null: false
      t.jsonb :granted_scopes, null: false, default: []
      t.string :state, limit: 32, null: false, default: "connected"
      t.integer :credential_revision, null: false, default: 1
      t.datetime :consented_at, null: false
      t.datetime :last_checked_at
      t.datetime :revoked_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :integration_connections, %i[organization_id id], unique: true,
      name: "index_integration_connections_on_tenant_identity"
    add_index :integration_connections, :consent_digest, unique: true
    add_index :integration_connections, %i[organization_id provider external_account_id], unique: true,
      where: "state <> 'revoked'", name: "index_integration_connections_on_active_account"
    add_foreign_key :integration_connections, :organizations, on_delete: :restrict
    add_foreign_key :integration_connections, :memberships,
      column: %i[organization_id connected_by_membership_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_integration_connections_tenant_member"
    add_check_constraint :integration_connections, "provider = 'search_console'",
      name: "integration_connections_provider_allowlist"
    add_check_constraint :integration_connections, "consent_kind = 'search_console_oauth'",
      name: "integration_connections_separate_consent"
    add_check_constraint :integration_connections, "consent_digest ~ '^[0-9a-f]{64}$'",
      name: "integration_connections_consent_digest_format"
    add_check_constraint :integration_connections,
      "jsonb_typeof(granted_scopes) = 'array' AND octet_length(granted_scopes::text) <= 2048",
      name: "integration_connections_scopes_shape"
    add_check_constraint :integration_connections,
      "state IN ('connected', 'healthy', 'degraded', 'reauthorization_required', 'revoked')",
      name: "integration_connections_state_allowlist"
    add_check_constraint :integration_connections,
      "credential_revision > 0 AND ((state = 'revoked' AND revoked_at IS NOT NULL) OR " \
        "(state <> 'revoked' AND revoked_at IS NULL))",
      name: "integration_connections_lifecycle"
  end

  def add_selection_binding
    change_table :domain_verifications, bulk: true do |t|
      t.uuid :integration_connection_id
      t.text :provider_property_identifier
      t.string :provider_property_type, limit: 24
      t.string :provider_permission_level, limit: 32
      t.datetime :provider_checked_at
      t.integer :connection_revision
    end
    add_index :domain_verifications, %i[organization_id integration_connection_id],
      name: "index_domain_verifications_on_integration"
    add_foreign_key :domain_verifications, :integration_connections,
      column: %i[organization_id integration_connection_id],
      primary_key: %i[organization_id id], on_delete: :restrict,
      name: "fk_domain_verifications_tenant_integration"
    add_check_constraint :domain_verifications, search_console_binding_check,
      name: "domain_verifications_search_console_binding"
  end

  def search_console_binding_check
    <<~SQL.squish
      (method = 'search_console'
        AND integration_connection_id IS NOT NULL
        AND provider_property_identifier IS NOT NULL
        AND char_length(provider_property_identifier) BETWEEN 1 AND 2048
        AND provider_property_type IN ('url_prefix', 'domain')
        AND provider_permission_level IN ('siteOwner', 'siteFullUser', 'siteRestrictedUser', 'siteUnverifiedUser')
        AND provider_checked_at IS NOT NULL
        AND connection_revision > 0)
      OR
      (method <> 'search_console'
        AND integration_connection_id IS NULL
        AND provider_property_identifier IS NULL
        AND provider_property_type IS NULL
        AND provider_permission_level IS NULL
        AND provider_checked_at IS NULL
        AND connection_revision IS NULL)
    SQL
  end

  def replace_failure_constraints(categories)
    allowed = categories.map { |category| connection.quote(category) }.join(", ")
    FAILURE_CONSTRAINTS.each do |table, name|
      remove_check_constraint table, name: name
      add_check_constraint table, "failure_category IS NULL OR failure_category IN (#{allowed})",
        name: name, validate: false
      validate_check_constraint table, name: name
    end
  end

  def protect_selection_binding
    execute <<~SQL
      CREATE OR REPLACE FUNCTION protect_domain_verification_binding() RETURNS trigger AS $$
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
          OR NEW.integration_connection_id IS DISTINCT FROM OLD.integration_connection_id
          OR NEW.provider_property_identifier IS DISTINCT FROM OLD.provider_property_identifier
          OR NEW.provider_property_type IS DISTINCT FROM OLD.provider_property_type
          OR NEW.connection_revision IS DISTINCT FROM OLD.connection_revision
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'domain verification binding cannot be changed';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def invalidate_connection_bound_verifications
    execute <<~SQL
      CREATE FUNCTION invalidate_connection_bound_verifications() RETURNS trigger AS $$
      BEGIN
        IF NEW.external_account_id IS DISTINCT FROM OLD.external_account_id
          OR NEW.granted_scopes IS DISTINCT FROM OLD.granted_scopes
          OR NEW.credential_revision IS DISTINCT FROM OLD.credential_revision
          OR (NEW.state IS DISTINCT FROM OLD.state
            AND NEW.state IN ('reauthorization_required', 'revoked')) THEN
          WITH affected AS (
            UPDATE domain_verifications
            SET state = 'revoked', revoked_at = CURRENT_TIMESTAMP,
              failed_at = NULL, expired_at = NULL, failure_category = NULL,
              lock_version = lock_version + 1, updated_at = CURRENT_TIMESTAMP
            WHERE organization_id = NEW.organization_id
              AND integration_connection_id = NEW.id
              AND method = 'search_console'
              AND state IN ('pending', 'verified')
            RETURNING organization_id, project_id, property_id, environment_id
          )
          UPDATE properties
          SET verification_status = 'unverified', verified_at = NULL,
            lock_version = lock_version + 1, updated_at = CURRENT_TIMESTAMP
          WHERE EXISTS (
            SELECT 1 FROM affected
            JOIN property_environments ON
              property_environments.organization_id = affected.organization_id
              AND property_environments.project_id = affected.project_id
              AND property_environments.property_id = affected.property_id
              AND property_environments.id = affected.environment_id
              AND property_environments."primary" = TRUE
            WHERE properties.organization_id = affected.organization_id
              AND properties.project_id = affected.project_id
              AND properties.id = affected.property_id
          );
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER integration_connections_invalidate_verifications
      AFTER UPDATE OF external_account_id, granted_scopes, credential_revision, state
      ON integration_connections
      FOR EACH ROW EXECUTE FUNCTION invalidate_connection_bound_verifications();
    SQL
  end

  def restore_original_binding_protection
    execute <<~SQL
      CREATE OR REPLACE FUNCTION protect_domain_verification_binding() RETURNS trigger AS $$
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
    SQL
  end
end
