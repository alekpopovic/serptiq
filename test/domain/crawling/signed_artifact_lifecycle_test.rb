# frozen_string_literal: true

require "test_helper"

class CrawlingSignedArtifactLifecycleTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "artifact-lifecycle")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "artifact-project")
    @property = create_property_for(@owner, project: @project)
    @artifact = Crawling::ArtifactReference.new(
      organization_id: @owner.organization.id,
      project_id: @project.id,
      property_id: @property.id,
      object_key: "organizations/#{@owner.organization.id}/projects/#{@project.id}/" \
        "properties/#{@property.id}/report.json"
    )
    @signed_keys = []
    @signer = ->(key) { @signed_keys << key; "https://objects.example.test/signed" }
  end

  test "signed URLs require an active exact-tenant project and property" do
    assert_equal "https://objects.example.test/signed", Crawling::Public.signed_artifact_url(
      actor_membership: @owner.membership,
      artifact: @artifact,
      signer: @signer
    )

    at = Time.current.change(usec: 0)
    Administration::Public.request_resource_deletion(
      actor_membership: @owner.membership,
      target_type: "Property",
      project_id: @project.id,
      property_id: @property.id,
      current_session: issue_identity_session(user: @owner.membership.user, at: at).session,
      user_id: @owner.membership.user_id,
      clock: -> { at }
    )
    assert_raises(Shared::Public::AuthorizationError) do
      Crawling::Public.signed_artifact_url(
        actor_membership: @owner.membership,
        artifact: @artifact,
        signer: @signer
      )
    end

    foreign = create_organization_for(slug: "artifact-foreign")
    assert_raises(Shared::Public::AuthorizationError) do
      Crawling::Public.signed_artifact_url(
        actor_membership: foreign.membership,
        artifact: @artifact,
        signer: @signer
      )
    end
    assert_equal 1, @signed_keys.length
  end

  test "artifact references cannot substitute an object key outside their exact hierarchy" do
    assert_raises(ArgumentError) do
      Crawling::ArtifactReference.new(
        organization_id: @owner.organization.id,
        project_id: @project.id,
        property_id: @property.id,
        object_key: "organizations/#{SecureRandom.uuid}/private/report.json"
      )
    end
    assert_empty @signed_keys
  end
end
