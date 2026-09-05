# frozen_string_literal: true

module Usage
  class RecordAuthorizedCorrection
    def initialize(authorizer: ManualAdjustmentAuthorizer.new, recorder: RecordCorrection.new)
      @authorizer = authorizer
      @recorder = recorder
    end

    def call(organization_id:, actor_membership:, authorization:, **attributes)
      @authorizer.call(
        organization_id: organization_id,
        actor_membership: actor_membership,
        authorization: authorization
      )
      @recorder.call(
        organization_id: organization_id,
        actor_membership_id: actor_membership.id,
        **attributes
      )
    end
  end
end
