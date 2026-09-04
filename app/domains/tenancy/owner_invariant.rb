# frozen_string_literal: true

module Tenancy
  class OwnerInvariant
    State = Data.define(:organization, :ownership, :membership) do
      def initialize(organization:, ownership:, membership:)
        super
        freeze
      end
    end

    def lock!(organization_id:)
      organization = Organization.lock.find(organization_id)
      ownership = OrganizationOwnership.lock.find_by(
        id: organization.current_ownership_id,
        organization_id: organization.id,
        ended_at: nil
      )
      membership = ownership && Membership.lock.find_by(
        id: ownership.membership_id,
        organization_id: organization.id,
        status: "active"
      )
      unless ownership && membership
        Audit.emit(
          "organization.owner_invariant_violation",
          severity: :error,
          organization_id: organization.id,
          outcome: "failed",
          operation: "verify_owner"
        )
        raise OwnerInvariantViolation
      end

      State.new(organization: organization, ownership: ownership, membership: membership)
    rescue ActiveRecord::RecordNotFound
      raise OwnerInvariantViolation, cause: nil
    end

    def protect_deactivation!(state:, target_membership_id:, actor_membership_id:)
      if state.membership.id.to_s == target_membership_id.to_s
        Audit.emit(
          "membership.owner_invariant_blocked",
          severity: :error,
          organization_id: state.organization.id,
          outcome: "denied",
          operation: "membership_change",
          reason_code: "last_owner_transfer_required",
          actor_membership_id: actor_membership_id,
          subject_membership_id: target_membership_id
        )
        raise LastOwnerConflict
      end

      true
    end

    def require_current_owner!(state:, actor_membership_id:)
      raise OrganizationAccessDenied unless state.membership.id.to_s == actor_membership_id.to_s

      state.membership
    end
  end
end
