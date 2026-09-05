# frozen_string_literal: true

require "test_helper"

class CrawlingArtifactLifecycleTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @at = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "artifact-lifecycle")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "artifact-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property, at: @at)
    @scan = run_scan_to(@scan, "running", at: @at + 1.minute)
    @store = TestSupport::FakeArtifactStore.new
    @body = "<html>private customer page</html>"
  end

  test "captures complete metadata and safely deduplicates only inside one property" do
    first = capture(source_id: SecureRandom.uuid)
    second = capture(source_id: SecureRandom.uuid)

    assert_equal 1, Crawling::ArtifactBlob.count
    assert_equal 2, Crawling::Artifact.count
    artifact = Crawling::Artifact.find(first.artifact_id)
    assert_equal @scan.id, artifact.scan_id
    assert_equal "crawl_source", artifact.source_type
    assert_equal "raw_html", artifact.kind
    assert_equal "text/html", artifact.media_type
    assert_equal "customer-secret.html", artifact.download_filename
    assert_equal @body.bytesize, artifact.blob.byte_count
    assert_equal Digest::SHA256.hexdigest(@body), artifact.blob.content_sha256
    assert_equal "provider_managed", artifact.blob.encryption_mode
    assert_equal "v1", artifact.blob.encryption_key_version
    assert_equal first.organization_id, second.organization_id
    refute_includes artifact.blob.object_key, "customer"
    refute_includes artifact.blob.object_key, "?"
  end

  test "capture retry is idempotent after a partial adapter failure" do
    source_id = SecureRandom.uuid
    @store.fail_after_bytes = 8
    assert_raises(Crawling::ArtifactStore::Error) { capture(source_id: source_id) }
    assert_equal 1, Crawling::ArtifactBlob.count
    assert_equal "uploading", Crawling::ArtifactBlob.sole.state
    assert_equal 0, Crawling::Artifact.count

    @store.fail_after_bytes = nil
    reference = capture(source_id: source_id)
    assert_equal 2, @store.upload_attempts
    assert Crawling::Artifact.find(reference.artifact_id).downloadable?
    assert_equal @body, @store.body(Crawling::ArtifactBlob.sole.object_key)
  end

  test "same source with different content is rejected without replacing its object" do
    source_id = SecureRandom.uuid
    capture(source_id: source_id)
    error = assert_raises(Crawling::Conflict) { capture(source_id: source_id, body: "changed") }
    assert_equal "artifact_source_conflict", error.reason_code
    assert_equal 1, Crawling::Artifact.count
    assert_equal 1, Crawling::ArtifactBlob.count
  end

  test "capture rejects a raw URL source identifier before persisting metadata" do
    assert_raises(Crawling::Invalid) do
      capture(source_id: "https://customer.example/private?token=secret")
    end
    assert_equal 0, Crawling::Artifact.count
    assert_equal 0, Crawling::ArtifactBlob.count
  end

  test "cross tenant content has distinct metadata and storage keys" do
    capture(source_id: SecureRandom.uuid)
    foreign = create_organization_for(slug: "artifact-foreign")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    project = create_project_for(foreign, slug: "foreign-project")
    property = create_property_for(foreign, project: project)
    scan = create_scan_for(foreign, project: project, property: property, at: @at)
    scan = run_scan_to(scan, "running", at: @at + 1.minute)
    capture_for(foreign, project, property, scan, source_id: SecureRandom.uuid)

    assert_equal 2, Crawling::ArtifactBlob.count
    keys = Crawling::ArtifactBlob.order(:organization_id).pluck(:object_key)
    assert_equal 2, keys.uniq.length
    assert keys.all? { |key| key.match?(%r{/objects/[0-9a-f]{2}/[0-9a-f-]{36}\z}) }
  end

  test "signed retrieval reloads server metadata and denies cross tenant or inactive resources" do
    reference = capture(source_id: SecureRandom.uuid)
    calls = []
    signer = ->(**arguments) { calls << arguments; "https://objects.example.test/private" }
    url = Crawling::SignArtifact.new(store: @store).call(
      actor_membership: @owner.membership, artifact: reference, signer: signer, expires_in: 90
    )
    assert_equal "https://objects.example.test/private", url
    assert_equal reference.artifact_id, calls.sole.fetch(:artifact_id)
    refute_includes url, Crawling::Artifact.find(reference.artifact_id).blob.object_key

    foreign = create_organization_for(slug: "artifact-reader-foreign")
    assert_raises(Shared::Public::AuthorizationError) do
      Crawling::SignArtifact.new(store: @store).call(
        actor_membership: foreign.membership, artifact: reference, signer: signer
      )
    end
    forged = Crawling::ArtifactReference.new(
      organization_id: reference.organization_id, project_id: reference.project_id,
      property_id: SecureRandom.uuid, artifact_id: reference.artifact_id
    )
    assert_raises(Shared::Public::AuthorizationError) do
      Crawling::SignArtifact.new(store: @store).call(
        actor_membership: @owner.membership, artifact: forged, signer: signer
      )
    end
    assert_equal 1, calls.length
  end

  test "retention excludes legal holds and deletes shared content only after its last reference" do
    first = capture(source_id: SecureRandom.uuid, expires_at: @at + 1.hour)
    second = capture(source_id: SecureRandom.uuid, expires_at: @at + 2.hours)
    held = capture(source_id: SecureRandom.uuid, body: "held", expires_at: @at + 1.hour)
    Crawling::SetArtifactLegalHold.new(clock: -> { @at + 10.minutes }).call(
      organization_id: @owner.organization.id, artifact_id: held.artifact_id, enabled: true
    )

    expired = Crawling::ExpireArtifacts.new(clock: -> { @at + 90.minutes }).call
    assert_equal [ first.artifact_id ], expired
    assert_equal :deleted, Crawling::DeleteArtifact.new(store: @store, clock: -> { @at + 90.minutes })
      .call(artifact_id: first.artifact_id)
    assert_equal "active", Crawling::Artifact.find(second.artifact_id).blob.state
    assert_equal "retained", Crawling::Artifact.find(held.artifact_id).retention_state

    assert_equal [ second.artifact_id ], Crawling::ExpireArtifacts.new(clock: -> { @at + 3.hours }).call
    assert_equal :deleted, Crawling::DeleteArtifact.new(store: @store, clock: -> { @at + 3.hours })
      .call(artifact_id: second.artifact_id)
    assert_equal "deleted", Crawling::ArtifactBlob.find_by(content_sha256: Digest::SHA256.hexdigest(@body)).state
    assert_equal :deleted, Crawling::DeleteArtifact.new(store: @store).call(artifact_id: second.artifact_id)
  end

  test "resource lifecycle pauses before deleting metadata covered by a legal hold" do
    reference = capture(source_id: SecureRandom.uuid)
    Crawling::SetArtifactLegalHold.new(clock: -> { @at }).call(
      organization_id: @owner.organization.id, artifact_id: reference.artifact_id, enabled: true
    )

    error = assert_raises(Crawling::ArtifactLifecycleBlocked) do
      Crawling::DeleteForLifecycle.new.call(
        organization_id: @owner.organization.id, project_id: @project.id,
        property_id: @property.id, deletion_workflow_id: SecureRandom.uuid
      )
    end
    assert_equal "artifact_legal_hold", error.reason_code
    assert Crawling::Artifact.exists?(reference.artifact_id)
    assert Crawling::Scan.exists?(@scan.id)
  end

  test "deletion failure remains retryable and idempotent" do
    reference = capture(source_id: SecureRandom.uuid, expires_at: @at + 1.hour)
    Crawling::ExpireArtifacts.new(clock: -> { @at + 2.hours }).call
    @store.fail_delete = true
    assert_raises(Crawling::ArtifactStore::Error) do
      Crawling::DeleteArtifact.new(store: @store).call(artifact_id: reference.artifact_id)
    end
    assert_equal "deletion_pending", Crawling::Artifact.find(reference.artifact_id).retention_state
    assert_equal "active", Crawling::Artifact.find(reference.artifact_id).blob.state

    @store.fail_delete = false
    assert_equal :deleted, Crawling::DeleteArtifact.new(store: @store).call(artifact_id: reference.artifact_id)
    assert_equal :deleted, Crawling::DeleteArtifact.new(store: @store).call(artifact_id: reference.artifact_id)
  end

  test "reconciliation records missing objects and removes scoped orphans idempotently" do
    reference = capture(source_id: SecureRandom.uuid)
    artifact = Crawling::Artifact.find(reference.artifact_id)
    @store.delete(key: artifact.blob.object_key)
    result = Crawling::ReconcileArtifacts.new(store: @store, clock: -> { @at + 1.hour }).call(
      organization_id: artifact.organization_id, project_id: artifact.project_id, property_id: artifact.property_id
    )
    assert_equal 1, result.missing_count
    assert_equal "missing", artifact.reload.retention_state
    assert_equal "missing", artifact.blob.reload.state

    orphan = Crawling::ArtifactKey.generate(
      organization_id: artifact.organization_id, project_id: artifact.project_id, property_id: artifact.property_id
    )
    @store.seed(orphan, "orphan")
    result = Crawling::ReconcileArtifacts.new(store: @store).call(
      organization_id: artifact.organization_id, project_id: artifact.project_id,
      property_id: artifact.property_id, reconcile_orphans: true
    )
    assert_equal 1, result.orphan_deleted_count
    refute @store.exist?(key: orphan)
    assert_equal 0, Crawling::ReconcileArtifacts.new(store: @store).call(
      organization_id: artifact.organization_id, project_id: artifact.project_id,
      property_id: artifact.property_id, reconcile_orphans: true
    ).orphan_deleted_count
  end

  test "reconciliation removes an unreferenced completed upload after its crash grace period" do
    body = "unreferenced"
    key = Crawling::ArtifactKey.generate(
      organization_id: @owner.organization.id, project_id: @project.id, property_id: @property.id
    )
    blob = Crawling::ArtifactBlob.create!(
      organization_id: @owner.organization.id, project_id: @project.id, property_id: @property.id,
      storage_service: "local", object_key: key, byte_count: body.bytesize,
      content_sha256: Digest::SHA256.hexdigest(body), encryption_mode: "provider_managed",
      encryption_key_version: "v1", state: "active", stored_at: @at - 2.hours,
      created_at: @at - 2.hours, updated_at: @at - 2.hours
    )
    @store.seed(key, body)

    result = Crawling::ReconcileArtifacts.new(store: @store, clock: -> { @at }).call(
      organization_id: @owner.organization.id, project_id: @project.id, property_id: @property.id
    )
    assert_equal 1, result.unreferenced_deleted_count
    assert_equal "deleted", blob.reload.state
    refute @store.exist?(key: key)
  end

  test "storage metrics attribute unique bytes and logical references to the tenant project" do
    capture(source_id: SecureRandom.uuid)
    capture(source_id: SecureRandom.uuid)
    metric = Crawling::ArtifactStorageMetrics.new.call(
      organization_id: @owner.organization.id, project_id: @project.id
    ).sole
    assert_equal @owner.organization.id, metric.organization_id
    assert_equal @project.id, metric.project_id
    assert_equal 1, metric.object_count
    assert_equal 2, metric.reference_count
    assert_equal @body.bytesize, metric.byte_count
  end

  private

  def capture(source_id:, body: @body, expires_at: @at + 1.day)
    capture_for(@owner, @project, @property, @scan, source_id: source_id, body: body, expires_at: expires_at)
  end

  def capture_for(owner, project, property, scan, source_id:, body: @body, expires_at: @at + 1.day)
    Crawling::CaptureArtifact.new(store: @store, clock: -> { @at }).call(
      organization_id: owner.organization.id, project_id: project.id, property_id: property.id,
      environment_id: scan.environment_id, scan_id: scan.id, source_type: "crawl_source",
      source_id: source_id, kind: "raw_html", media_type: "text/html",
      filename: "../../customer\r\nsecret.html", retention_class: "raw_crawl",
      retention_expires_at: expires_at, io: StringIO.new(body)
    )
  end
end
