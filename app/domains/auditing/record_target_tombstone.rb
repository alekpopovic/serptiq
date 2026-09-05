# frozen_string_literal: true

module Auditing
  class RecordTargetTombstone
    def call(organization_id:, deletion_workflow_id:, target_type:, target_id:, project_id:,
      property_id: nil, deleted_at: Time.current)
      TargetTombstone.create_or_find_by!(
        organization_id: organization_id,
        target_type: target_type,
        target_id: target_id
      ) do |tombstone|
        tombstone.assign_attributes(
          deletion_workflow_id: deletion_workflow_id,
          project_id: project_id,
          property_id: property_id,
          deleted_at: deleted_at,
          created_at: deleted_at
        )
      end
    end
  end
end
