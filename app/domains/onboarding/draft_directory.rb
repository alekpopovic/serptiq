# frozen_string_literal: true

module Onboarding
  class DraftDirectory
    def initialize(access: Access.new)
      @access = access
    end

    def active(actor_membership:, organization_id:)
      @access.authorize!(actor_membership: actor_membership, organization_id: organization_id)
      Draft.active.find_by(
        organization_id: organization_id, actor_membership_id: actor_membership.id
      )
    end

    def find(actor_membership:, organization_id:, draft_id:)
      @access.draft!(
        actor_membership: actor_membership,
        organization_id: organization_id,
        draft_id: draft_id
      )
    end
  end
end
