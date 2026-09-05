# frozen_string_literal: true

module Crawling
  class DeleteArtifact
    def initialize(store: ArtifactStoreFactory.build, clock: -> { Time.current })
      @store = store
      @clock = clock
    end

    def call(artifact_id:)
      artifact = Artifact.includes(:blob).find_by(id: artifact_id)
      return :missing unless artifact
      return :deleted if artifact.retention_state == "deleted"
      return :held if artifact.legal_hold?
      raise Conflict.new(reason_code: "artifact_not_pending_deletion") unless
        artifact.retention_state.in?(%w[deletion_pending missing])

      blob = artifact.blob
      delete_object = false
      ArtifactBlob.transaction do
        blob.lock!
        artifact.lock!
        active_sibling = Artifact.where(artifact_blob_id: blob.id, retention_state: "retained").exists?
        unless active_sibling
          blob.update!(state: "deleting") unless blob.state.in?(%w[missing deleted])
          delete_object = blob.state != "deleted"
        end
      end
      @store.delete(key: blob.object_key) if delete_object
      finish!(artifact, blob, delete_object)
      :deleted
    rescue ArtifactStore::Error
      blob&.update!(state: "active") if blob&.state == "deleting"
      raise
    end

    private

    def finish!(artifact, blob, delete_object)
      now = @clock.call
      Artifact.transaction do
        artifact.lock!
        artifact.update!(retention_state: "deleted", deleted_at: now)
        blob.lock!
        blob.update!(state: "deleted", deleted_at: now) if delete_object
      end
    end
  end
end
