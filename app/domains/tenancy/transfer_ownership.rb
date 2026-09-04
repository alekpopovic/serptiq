# frozen_string_literal: true

module Tenancy
  class TransferOwnership
    CONFIRMATION = "TRANSFER OWNERSHIP"

    def initialize(clock: -> { Time.current }, notifier: OwnershipTransferNotifier.new,
      identity: Identity::Public)
      @clock = clock
      @notifier = notifier
      @identity = identity
    end

    def call(actor_membership:, target_membership_id:, current_session:, session_metadata:,
      authorization:, confirmation:)
      raise OwnershipTransferConfirmationInvalid unless confirmation.to_s == CONFIRMATION

      result = OrganizationOwnership.transaction do
        session = @identity.verify_recent_session!(
          session: current_session,
          user_id: actor_membership.user_id,
          clock: @clock
        )
        owner_state = OwnerInvariant.new.lock!(organization_id: actor_membership.organization_id)
        organization = owner_state.organization
        actor = Membership.lock.find_by!(id: actor_membership.id, organization_id: organization.id)
        AuthorizeMembershipAccess.new.call(
          membership: actor,
          permission_key: "organization.transfer",
          authorization: authorization
        )
        OwnerInvariant.new.require_current_owner!(state: owner_state, actor_membership_id: actor.id)
        previous = owner_state.ownership

        target = Membership.lock.find_by!(id: target_membership_id, organization_id: organization.id)
        raise OwnershipTransferDenied.new(reason_code: "ownership_target_inactive") unless target.active?
        raise OwnershipTransferDenied.new(reason_code: "ownership_target_unchanged") if target.id == actor.id

        transfer_locked!(organization, previous, actor, target, session, session_metadata)
      end
      emit_success(result)
      @notifier.call(result)
      result
    rescue ActiveRecord::RecordNotFound
      error = OwnershipTransferDenied.new(reason_code: "ownership_target_invalid")
      emit_rejection(actor_membership, target_membership_id, error)
      raise error, cause: nil
    rescue StandardError => error
      emit_rejection(actor_membership, target_membership_id, error)
      raise
    end

    private

    def transfer_locked!(organization, previous, actor, target, session, session_metadata)
      now = @clock.call
      replacement = OrganizationOwnership.create!(
        organization: organization,
        membership: target,
        assigned_at: now,
        ended_at: now,
        current: false,
        membership_status: nil
      )
      organization.update!(current_ownership: replacement)
      previous.update!(ended_at: now, current: false, membership_status: nil)
      replacement.update!(ended_at: nil, current: true, membership_status: "active")
      revoked = @identity.sessions_after_ownership_received!(user_id: target.user_id, clock: @clock)
      issued = @identity.sessions_after_ownership_transfer!(
        current_session: session,
        metadata: session_metadata,
        clock: @clock
      )
      OwnershipTransferResult.new(
        organization: organization,
        previous_ownership: previous,
        current_ownership: replacement,
        previous_owner: actor,
        current_owner: target,
        issued_session: issued,
        revoked_current_owner_sessions: revoked
      )
    end

    def emit_success(result)
      Audit.emit(
        "organization.ownership_transferred",
        severity: :error,
        organization_id: result.organization.id,
        outcome: "succeeded",
        operation: "transfer_ownership",
        actor_membership_id: result.previous_owner.id,
        subject_membership_id: result.current_owner.id
      )
    end

    def emit_rejection(actor, target_id, error)
      Audit.emit(
        "organization.ownership_transfer_rejected",
        severity: :error,
        organization_id: actor&.organization_id,
        outcome: "denied",
        operation: "transfer_ownership",
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : "ownership_transfer_failed",
        actor_membership_id: actor&.id,
        subject_membership_id: target_id
      )
    end
  end
end
