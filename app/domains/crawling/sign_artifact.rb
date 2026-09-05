# frozen_string_literal: true

module Crawling
  class SignArtifact
    MAX_TTL = 15.minutes

    def initialize(store: ArtifactStoreFactory.build)
      @store = store
    end

    def call(actor_membership:, artifact:, expires_in: 5.minutes, signer: nil)
      raise AccessDenied.new(reason_code: "artifact_resource_unavailable") unless
        artifact.is_a?(ArtifactReference)

      organization_id = actor_membership&.organization_id
      raise AccessDenied.new(reason_code: "artifact_resource_unavailable") unless
        artifact.organization_id == organization_id.to_s

      record = Artifact.includes(:blob).find_by(
        id: artifact.artifact_id, organization_id: artifact.organization_id,
        project_id: artifact.project_id, property_id: artifact.property_id
      )
      raise AccessDenied.new(reason_code: "artifact_resource_unavailable") unless record&.downloadable?

      project = Projects::Public.reference(
        organization_id: organization_id,
        project_id: artifact.project_id
      )
      property = Properties::Public.reference(
        organization_id: organization_id,
        project_id: artifact.project_id,
        property_id: artifact.property_id
      )
      raise AccessDenied.new(reason_code: "artifact_resource_unavailable") unless
        project&.active? && property&.active?

      Authorization::Public.authorize_access!(
        actor_membership: actor_membership,
        permission_key: "scans.read",
        organization: organization_id,
        project: project,
        property: property
      )
      ttl = Float(expires_in)
      raise ArgumentError, "artifact URL lifetime is invalid" unless ttl.between?(1, MAX_TTL.to_f)

      arguments = {
        key: record.blob.object_key, artifact_id: record.id, expires_in: ttl,
        filename: record.download_filename, media_type: record.media_type
      }
      signer ? signer.call(**arguments) : @store.signed_url(**arguments)
    end
  end
end
