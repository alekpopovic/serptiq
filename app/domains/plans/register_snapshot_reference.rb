# frozen_string_literal: true

module Plans
  class RegisterSnapshotReference
    def call(plan_version_id:, reference_type:, reference_id:, clock: -> { Time.current })
      raise ArgumentError, "reference ID is invalid" unless Shared::Public.application_uuid?(reference_id)

      PlanVersionSnapshotReference.transaction do
        version = PlanVersion.lock.find(plan_version_id)
        raise CatalogTransitionInvalid.new(reason_code: "draft_plan_snapshot_reference") if version.status == "draft"

        PlanVersionSnapshotReference.create_or_find_by!(
          plan_version_id: version.id,
          reference_type: reference_type.to_s,
          reference_id: reference_id.to_s
        ) { |reference| reference.created_at = clock.call }
      end
    rescue ActiveRecord::RecordNotFound
      raise CatalogTransitionInvalid.new(reason_code: "plan_version_not_found"), cause: nil
    end
  end
end
