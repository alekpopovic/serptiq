# frozen_string_literal: true

module Onboarding
  class CancelDraft
    def initialize(access: Access.new)
      @access = access
    end

    def call(actor_membership:, organization_id:, draft_id:)
      step = Draft.transaction do
        draft = @access.draft!(
          actor_membership: actor_membership,
          organization_id: organization_id,
          draft_id: draft_id,
          lock: true
        )
        raise Conflict.new(reason_code: "onboarding_already_completed") unless draft.draft?

        current_step = draft.current_step
        draft.destroy!
        current_step
      end
      Instrumentation.abandoned(step)
      true
    end
  end
end
