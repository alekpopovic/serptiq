# frozen_string_literal: true

module Crawling
  class SetArtifactLegalHold
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    # Placeholder domain boundary for a future approved legal/compliance workflow.
    # It is intentionally not exposed through a customer controller.
    def call(organization_id:, artifact_id:, enabled:)
      artifact = Artifact.find_by!(organization_id: organization_id, id: artifact_id)
      artifact.with_lock do
        raise Conflict.new(reason_code: "artifact_already_deleted") if artifact.retention_state == "deleted"

        artifact.update!(legal_hold: !!enabled, legal_hold_set_at: enabled ? @clock.call : nil)
      end
      artifact
    end
  end
end
