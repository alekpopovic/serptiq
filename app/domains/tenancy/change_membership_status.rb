# frozen_string_literal: true

module Tenancy
  class ChangeMembershipStatus
    TRANSITIONS = {
      "suspend" => { "active" => "suspended" },
      "reactivate" => { "suspended" => "active" },
      "remove" => { "active" => "removed", "suspended" => "removed", "invited" => "removed" }
    }.freeze
    EVENT_NAMES = {
      "suspend" => "membership.suspended",
      "reactivate" => "membership.reactivated",
      "remove" => "membership.removed"
    }.freeze

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(actor_membership:, target_membership_id:, operation:, authorization: nil)
      operation = operation.to_s
      transition = TRANSITIONS.fetch(operation) { raise InvalidMembershipTransition }
      target = Membership.transaction do
        owner_state = OwnerInvariant.new.lock!(organization_id: actor_membership&.organization_id)
        actor = lock_actor(actor_membership)
        raise OrganizationAccessDenied unless actor.organization_id == owner_state.organization.id

        organization = owner_state.organization
        permission_key = operation == "remove" ? "members.remove" : "members.update"
        AuthorizeMembershipAccess.new.call(
          membership: actor, permission_key: permission_key, authorization: authorization
        )
        target = Membership.lock.find_by!(id: target_membership_id, organization_id: organization.id)
        OwnerInvariant.new.protect_deactivation!(
          state: owner_state,
          target_membership_id: target.id,
          actor_membership_id: actor.id
        )

        destination = transition[target.status]
        raise InvalidMembershipTransition unless destination

        apply_transition(target, destination, @clock.call)
        target.save!
        Identity::Public.revoke_sessions_after_membership_deactivation!(user_id: target.user_id) unless target.active?
        target
      end
      emit(EVENT_NAMES.fetch(operation), operation, actor_membership, target)
      target
    rescue StandardError => error
      public_error = error.is_a?(ActiveRecord::RecordNotFound) ? OrganizationAccessDenied.new : error
      emit_rejection(operation, actor_membership, target_membership_id, public_error)
      raise public_error, cause: nil if public_error != error

      raise
    end

    private

    def lock_actor(actor_membership)
      raise OrganizationAccessDenied unless actor_membership.is_a?(Membership)

      actor = Membership.lock.find(actor_membership.id)
      raise OrganizationAccessDenied unless actor.active?

      actor
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end

    def apply_transition(target, destination, now)
      target.status = destination
      case destination
      when "active"
        target.suspended_at = nil
      when "suspended"
        target.suspended_at = now
      when "removed"
        target.suspended_at = nil
        target.removed_at = now
      end
    end

    def emit(event_name, operation, actor, target)
      Audit.emit(
        event_name,
        outcome: "succeeded",
        operation: operation,
        actor_membership_id: actor.id,
        subject_membership_id: target.id
      )
    end

    def emit_rejection(operation, actor, target_id, error)
      Audit.emit(
        "membership.transition_rejected",
        outcome: "denied",
        operation: operation.presence || "unknown",
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : nil,
        actor_membership_id: actor&.id,
        subject_membership_id: target_id
      )
    end
  end
end
