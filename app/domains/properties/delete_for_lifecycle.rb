# frozen_string_literal: true

module Properties
  class DeleteForLifecycle
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, project_id:, deletion_workflow_id:, property_id: nil)
      relation = Property.where(organization_id: organization_id, project_id: project_id)
      relation = relation.where(id: property_id) if property_id
      properties = relation.order(:id).to_a
      if property_id && (
        properties.one? == false ||
        !properties.first.pending_deletion? ||
        properties.first.deletion_workflow_id != deletion_workflow_id
      )
        raise PropertyAccessDenied
      end

      properties.each do |property|
        record_tombstones(property, deletion_workflow_id)
        delete_children(property)
      end
      relation.delete_all
      properties.length
    end

    private

    def record_tombstones(property, workflow_id)
      now = @clock.call
      property.environments.pluck(:id).each do |environment_id|
        Auditing::Public.record_target_tombstone!(
          organization_id: property.organization_id,
          deletion_workflow_id: workflow_id,
          target_type: "PropertyEnvironment",
          target_id: environment_id,
          project_id: property.project_id,
          property_id: property.id,
          deleted_at: now
        )
      end
      Auditing::Public.record_target_tombstone!(
        organization_id: property.organization_id,
        deletion_workflow_id: workflow_id,
        target_type: "Property",
        target_id: property.id,
        project_id: property.project_id,
        property_id: property.id,
        deleted_at: now
      )
      Auditing::Public.record!(
        organization_id: property.organization_id,
        action: "property.deleted",
        target_type: "Property",
        target_id: property.id,
        result: "succeeded",
        metadata: { operation: "retention_deletion", kind: property.kind },
        occurred_at: now
      )
      event = PropertyEvent.record!(
        property: property,
        event_type: "property.deleted",
        occurred_at: now,
        actor_membership_id: nil
      )
      PropertyEvent.enqueue(event)
    end

    def delete_children(property)
      Environment.where(property_id: property.id).delete_all
      WebsitePropertyConfig.where(property_id: property.id).delete_all
      AndroidPropertyConfig.where(property_id: property.id).delete_all
      IosPropertyConfig.where(property_id: property.id).delete_all
    end
  end
end
