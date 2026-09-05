# frozen_string_literal: true

module Verification
  class DeleteForLifecycle
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, project_id:, deletion_workflow_id:, property_id: nil)
      challenges = Challenge.where(organization_id: organization_id, project_id: project_id)
      challenges = challenges.where(property_id: property_id) if property_id
      challenge_targets = challenges.order(:id).pluck(:id, :property_id)
      challenge_targets.each do |challenge_id, challenge_property_id|
        Auditing::Public.record_target_tombstone!(
          organization_id: organization_id,
          deletion_workflow_id: deletion_workflow_id,
          target_type: "DomainVerification",
          target_id: challenge_id,
          project_id: project_id,
          property_id: challenge_property_id,
          deleted_at: @clock.call
        )
      end
      challenge_ids = challenge_targets.map(&:first)
      Attempt.where(domain_verification_id: challenge_ids).delete_all if challenge_ids.any?
      challenges.delete_all
      challenge_ids.length
    end
  end
end
