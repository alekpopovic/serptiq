# frozen_string_literal: true

require "test_helper"

class CrawlingPrivateArtifactsTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @at = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "private-artifact-download")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "download-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property, at: @at)
    @scan = run_scan_to(@scan, "running", at: @at + 1.minute)
    @store = Crawling::ArtifactStoreFactory.build
    @reference = Crawling::CaptureArtifact.new(store: @store, clock: -> { @at }).call(
      organization_id: @owner.organization.id, project_id: @project.id, property_id: @property.id,
      environment_id: @scan.environment_id, scan_id: @scan.id, source_type: "crawl_source",
      source_id: SecureRandom.uuid, kind: "raw_html", media_type: "text/html",
      filename: "../../unsafe\r\npage.html", retention_class: "raw_crawl",
      retention_expires_at: @at + 1.day, io: StringIO.new("<html>private</html>")
    )
  end

  teardown do
    artifact = Crawling::Artifact.includes(:blob).find_by(id: @reference&.artifact_id)
    @store.delete(key: artifact.blob.object_key) if artifact && @store.exist?(key: artifact.blob.object_key)
  end

  test "authorized issuance returns a bearer URL that streams with hardened headers" do
    url = Crawling::SignArtifact.new(store: @store).call(
      actor_membership: @owner.membership, artifact: @reference, expires_in: 60
    )
    artifact = Crawling::Artifact.find(@reference.artifact_id)
    refute_includes url, artifact.blob.object_key
    refute_includes url, "unsafe"

    get URI(url).request_uri
    assert_response :success
    assert_equal "<html>private</html>", response.body
    assert_equal "text/html", response.media_type
    assert_equal "attachment; filename=\"unsafe-page.html\"", response.headers.fetch("Content-Disposition")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_equal "nosniff", response.headers.fetch("X-Content-Type-Options")
  end

  test "tampered or expired tokens disclose no metadata" do
    get private_artifact_path(token: "tampered-secret-customer-url")
    assert_response :not_found
    refute_includes response.body, @project.name
    refute_includes response.body, Crawling::Artifact.find(@reference.artifact_id).blob.object_key
  end
end
