# frozen_string_literal: true

module Crawling
  class SignArtifact
    def call(actor_membership:, artifact:, signer:)
      raise AccessDenied.new(reason_code: "artifact_resource_unavailable") unless
        artifact.is_a?(ArtifactReference)

      organization_id = actor_membership&.organization_id
      raise AccessDenied.new(reason_code: "artifact_resource_unavailable") unless
        artifact.organization_id == organization_id.to_s

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
      signer.call(artifact.object_key)
    end
  end
end
