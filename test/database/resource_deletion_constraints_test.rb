# frozen_string_literal: true

require "test_helper"

class ResourceDeletionConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "deletion-constraints")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "protected-project")
    @property = create_property_for(@owner, project: @project)
  end

  test "aggregate rows cannot be physically deleted outside an exact active workflow stage" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Projects::Project.transaction(requires_new: true) do
        Projects::Project.where(id: @project.id).delete_all
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Properties::Property.transaction(requires_new: true) do
        Properties::Property.where(id: @property.id).delete_all
      end
    end

    assert Projects::Project.exists?(@project.id)
    assert Properties::Property.exists?(@property.id)
  end

  test "resource lifecycle shape and exact workflow foreign key are database enforced" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Projects::Project.transaction(requires_new: true) do
        @project.update_columns(
          status: "pending_deletion",
          archived_at: Time.current,
          deletion_requested_at: Time.current,
          deletion_workflow_id: SecureRandom.uuid
        )
      end
    end
  end
end
