# frozen_string_literal: true

class CreatePrivateArtifacts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BLOB_STATES = %w[uploading active missing deleting deleted].freeze
  RETENTION_STATES = %w[retained deletion_pending missing deleted].freeze

  def change
    add_index :properties, %i[organization_id project_id id], unique: true,
      algorithm: :concurrently, name: "index_properties_on_exact_identity" unless index_exists?(
        :properties, %i[organization_id project_id id], name: "index_properties_on_exact_identity"
      )

    create_table :artifact_blobs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.string :storage_service, limit: 24, null: false
      t.string :object_key, limit: 512, null: false
      t.bigint :byte_count, null: false
      t.string :content_sha256, limit: 64, null: false
      t.string :encryption_mode, limit: 32, null: false, default: "provider_managed"
      t.string :encryption_key_version, limit: 64, null: false
      t.string :state, limit: 24, null: false, default: "uploading"
      t.datetime :stored_at
      t.datetime :verified_at
      t.datetime :missing_at
      t.datetime :deleted_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :artifact_blobs, :projects,
      column: %i[organization_id project_id], primary_key: %i[organization_id id],
      on_delete: :restrict, name: "fk_artifact_blobs_exact_project"
    add_foreign_key :artifact_blobs, :properties,
      column: %i[organization_id project_id property_id],
      primary_key: %i[organization_id project_id id],
      on_delete: :restrict, name: "fk_artifact_blobs_exact_property"
    add_index :artifact_blobs, %i[organization_id project_id property_id id], unique: true,
      name: "index_artifact_blobs_on_exact_identity"
    add_index :artifact_blobs,
      %i[organization_id project_id property_id encryption_key_version content_sha256],
      unique: true, where: "state <> 'deleted'", name: "index_artifact_blobs_on_safe_deduplication"
    add_index :artifact_blobs, %i[state updated_at id], name: "index_artifact_blobs_on_reconciliation"
    add_check_constraint :artifact_blobs,
      "storage_service ~ '^[a-z][a-z0-9_]{0,23}$' AND byte_count >= 0 " \
        "AND content_sha256 ~ '^[0-9a-f]{64}$' " \
        "AND encryption_mode IN ('provider_managed', 'sse_s3', 'local_private') " \
        "AND encryption_key_version ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'",
      name: "artifact_blobs_metadata_shape"
    add_check_constraint :artifact_blobs,
      "octet_length(object_key) BETWEEN 32 AND 512 AND object_key !~ '[[:cntrl:]]' " \
        "AND object_key LIKE 'organizations/' || organization_id::text || '/projects/' || project_id::text || " \
        "'/properties/' || property_id::text || '/objects/%'",
      name: "artifact_blobs_opaque_scoped_key"
    add_check_constraint :artifact_blobs,
      "state IN (#{quote_list(BLOB_STATES)}) " \
        "AND (state <> 'uploading' OR (stored_at IS NULL AND missing_at IS NULL AND deleted_at IS NULL)) " \
        "AND (state <> 'active' OR (stored_at IS NOT NULL AND missing_at IS NULL AND deleted_at IS NULL)) " \
        "AND (state <> 'missing' OR (stored_at IS NOT NULL AND missing_at IS NOT NULL AND deleted_at IS NULL)) " \
        "AND (state <> 'deleted' OR deleted_at IS NOT NULL)",
      name: "artifact_blobs_lifecycle"

    create_table :artifacts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :project_id, null: false
      t.uuid :property_id, null: false
      t.uuid :environment_id, null: false
      t.uuid :scan_id, null: false
      t.uuid :artifact_blob_id, null: false
      t.string :source_type, limit: 48, null: false
      t.string :source_id, limit: 128, null: false
      t.string :kind, limit: 48, null: false
      t.string :media_type, limit: 128, null: false
      t.string :download_filename, limit: 160, null: false
      t.string :retention_class, limit: 48, null: false
      t.string :retention_state, limit: 24, null: false, default: "retained"
      t.datetime :retention_expires_at, null: false
      t.boolean :legal_hold, null: false, default: false
      t.datetime :legal_hold_set_at
      t.datetime :deletion_requested_at
      t.datetime :deleted_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :artifacts, :scans,
      column: %i[organization_id project_id property_id environment_id scan_id],
      primary_key: %i[organization_id project_id property_id environment_id id],
      on_delete: :restrict, name: "fk_artifacts_exact_scan"
    add_foreign_key :artifacts, :artifact_blobs,
      column: %i[organization_id project_id property_id artifact_blob_id],
      primary_key: %i[organization_id project_id property_id id],
      on_delete: :restrict, name: "fk_artifacts_exact_blob"
    add_index :artifacts, %i[organization_id project_id property_id scan_id id],
      name: "index_artifacts_on_tenant_scan"
    add_index :artifacts, %i[organization_id project_id property_id source_type source_id kind], unique: true,
      name: "index_artifacts_on_source_idempotency"
    add_index :artifacts, %i[artifact_blob_id retention_state legal_hold],
      name: "index_artifacts_on_blob_retention"
    add_index :artifacts, %i[retention_state legal_hold retention_expires_at id],
      name: "index_artifacts_on_retention_queue"
    add_check_constraint :artifacts,
      "source_type ~ '^[a-z][a-z0-9_]{0,47}$' AND octet_length(source_id) BETWEEN 1 AND 128 " \
        "AND source_id !~ '[[:cntrl:]]' AND kind ~ '^[a-z][a-z0-9_]{0,47}$' " \
        "AND media_type ~ '^[a-z0-9!#\$&^_.+-]+/[a-z0-9!#\$&^_.+-]+$' " \
        "AND octet_length(download_filename) BETWEEN 1 AND 160 " \
        "AND download_filename !~ '[[:cntrl:]/\\\\]' " \
        "AND retention_class ~ '^[a-z][a-z0-9_]{0,47}$'",
      name: "artifacts_metadata_shape"
    add_check_constraint :artifacts,
      "retention_state IN (#{quote_list(RETENTION_STATES)}) " \
        "AND ((legal_hold AND legal_hold_set_at IS NOT NULL) OR (NOT legal_hold AND legal_hold_set_at IS NULL)) " \
        "AND (retention_state = 'retained' OR deletion_requested_at IS NOT NULL) " \
        "AND (retention_state <> 'deleted' OR deleted_at IS NOT NULL)",
      name: "artifacts_retention_lifecycle"
  end

  private

  def quote_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
