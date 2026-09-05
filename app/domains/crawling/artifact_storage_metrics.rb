# frozen_string_literal: true

module Crawling
  ArtifactStorageMetric = Data.define(
    :organization_id, :project_id, :storage_service, :object_count, :byte_count, :reference_count
  )

  class ArtifactStorageMetrics
    def call(organization_id:, project_id: nil)
      blob_scope = ArtifactBlob.where(organization_id: organization_id, state: "active")
      artifact_scope = Artifact.where(organization_id: organization_id, retention_state: "retained")
      if project_id
        blob_scope = blob_scope.where(project_id: project_id)
        artifact_scope = artifact_scope.where(project_id: project_id)
      end
      blob_scope.group(:project_id, :storage_service).order(:project_id, :storage_service)
        .pluck(:project_id, :storage_service, Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(byte_count), 0)"))
        .map do |grouped_project_id, storage_service, object_count, byte_count|
        ArtifactStorageMetric.new(
          organization_id.to_s, grouped_project_id.to_s, storage_service,
          object_count, byte_count,
          artifact_scope.joins(:blob).where(artifact_blobs: {
            project_id: grouped_project_id, storage_service: storage_service, state: "active"
          }).count
        )
      end.freeze
    end
  end
end
