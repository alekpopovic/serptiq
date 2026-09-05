# frozen_string_literal: true

module Crawling
  class ReconcileArtifacts
    BATCH_SIZE = 250
    UNREFERENCED_GRACE = 1.hour

    Result = Data.define(:checked_count, :missing_count, :orphan_deleted_count, :unreferenced_deleted_count)

    def initialize(store: ArtifactStoreFactory.build, clock: -> { Time.current })
      @store = store
      @clock = clock
    end

    def call(organization_id: nil, project_id: nil, property_id: nil, batch_size: BATCH_SIZE,
      reconcile_orphans: false)
      scope = ArtifactBlob.where(state: "active").order(:updated_at, :id)
      scope = scope.where(organization_id: organization_id) if organization_id
      scope = scope.where(project_id: project_id) if project_id
      scope = scope.where(property_id: property_id) if property_id
      blobs = scope.limit(Integer(batch_size)).to_a
      missing = blobs.reject do |blob|
        exists = @store.exist?(key: blob.object_key)
        blob.update_columns(verified_at: @clock.call, updated_at: @clock.call) if exists
        exists
      end
      missing.each { |blob| record_missing!(blob) }
      orphan_count = reconcile_orphans ? delete_orphans!(organization_id, project_id, property_id, batch_size) : 0
      unreferenced_count = delete_unreferenced!(organization_id, project_id, property_id, batch_size)
      Result.new(blobs.length, missing.length, orphan_count, unreferenced_count)
    end

    private

    def record_missing!(blob)
      now = @clock.call
      ArtifactBlob.transaction do
        blob.lock!
        return unless blob.state == "active"

        blob.update!(state: "missing", missing_at: now)
        Artifact.where(artifact_blob_id: blob.id, retention_state: "retained", legal_hold: false)
          .update_all(retention_state: "missing", deletion_requested_at: now, updated_at: now)
      end
    end

    def delete_orphans!(organization_id, project_id, property_id, batch_size)
      raise ArgumentError, "orphan reconciliation requires an exact property scope" unless
        [ organization_id, project_id, property_id ].all?(&:present?)

      prefix = ArtifactKey.prefix(
        organization_id: organization_id, project_id: project_id, property_id: property_id
      )
      page = @store.list(prefix: prefix, limit: Integer(batch_size))
      known = ArtifactBlob.where(organization_id: organization_id, project_id: project_id, property_id: property_id)
        .where(object_key: page.entries.map(&:key)).pluck(:object_key).to_set
      orphans = page.entries.reject { |entry| known.include?(entry.key) }
      orphans.each { |entry| @store.delete(key: entry.key) }
      orphans.length
    end

    def delete_unreferenced!(organization_id, project_id, property_id, batch_size)
      scope = ArtifactBlob.left_outer_joins(:artifacts).where(state: "active", artifacts: { id: nil })
        .where(created_at: ..(@clock.call - UNREFERENCED_GRACE)).order(:created_at, :id)
      scope = scope.where(organization_id: organization_id) if organization_id
      scope = scope.where(project_id: project_id) if project_id
      scope = scope.where(property_id: property_id) if property_id
      scope.limit(Integer(batch_size)).count do |blob|
        delete_unreferenced_blob!(blob)
      end
    end

    def delete_unreferenced_blob!(blob)
      blob.with_lock do
        return false unless blob.state == "active" && !Artifact.where(artifact_blob_id: blob.id).exists?

        blob.update!(state: "deleting")
      end
      @store.delete(key: blob.object_key)
      blob.with_lock do
        blob.update!(state: "deleted", deleted_at: @clock.call)
      end
      true
    rescue ArtifactStore::Error
      blob.update!(state: "active") if blob.state == "deleting"
      raise
    end
  end
end
