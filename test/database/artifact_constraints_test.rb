# frozen_string_literal: true

require "test_helper"

class ArtifactConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "artifact-db-owner")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "artifact-db-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property)
  end

  test "database rejects a blob with a property from another project" do
    other = create_project_for(@owner, slug: "artifact-db-other")
    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      Crawling::ArtifactBlob.insert!({
        organization_id: @owner.organization.id, project_id: other.id, property_id: @property.id,
        storage_service: "local", object_key: Crawling::ArtifactKey.generate(
          organization_id: @owner.organization.id, project_id: other.id, property_id: @property.id
        ), byte_count: 1, content_sha256: Digest::SHA256.hexdigest("x"),
        encryption_mode: "local_private", encryption_key_version: "v1", state: "uploading",
        created_at: Time.current, updated_at: Time.current
      })
    end
    assert_match(/fk_artifact_blobs_exact_property/, error.message)
  end

  test "database rejects artifact metadata pointing at a scan from another tenant" do
    blob = Crawling::ArtifactBlob.create!(
      organization_id: @owner.organization.id, project_id: @project.id, property_id: @property.id,
      storage_service: "local", object_key: Crawling::ArtifactKey.generate(
        organization_id: @owner.organization.id, project_id: @project.id, property_id: @property.id
      ), byte_count: 1, content_sha256: Digest::SHA256.hexdigest("x"),
      encryption_mode: "local_private", encryption_key_version: "v1", state: "active", stored_at: Time.current
    )
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Crawling::Artifact.insert!({
        organization_id: @owner.organization.id, project_id: @project.id, property_id: @property.id,
        environment_id: @scan.environment_id, scan_id: SecureRandom.uuid, artifact_blob_id: blob.id,
        source_type: "crawl_source", source_id: SecureRandom.uuid, kind: "raw_html", media_type: "text/html",
        download_filename: "safe.html", retention_class: "raw_crawl", retention_state: "retained",
        retention_expires_at: 1.day.from_now, legal_hold: false, created_at: Time.current, updated_at: Time.current
      })
    end
  end
end
