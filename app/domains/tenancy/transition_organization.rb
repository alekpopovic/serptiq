# frozen_string_literal: true

module Tenancy
  class TransitionOrganization
    TRANSITIONS = {
      "active" => %w[suspended pending_deletion],
      "suspended" => %w[active pending_deletion],
      "pending_deletion" => %w[deleted],
      "deleted" => []
    }.freeze

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(actor_membership:, to:)
      organization = Organization.transaction do
        membership = Membership.lock.find(actor_membership&.id)
        target = Organization.lock.find(membership.organization_id)
        authorize_owner!(membership, target)
        destination = to.to_s
        raise InvalidOrganizationTransition unless TRANSITIONS.fetch(target.status).include?(destination)

        apply_transition(target, destination, @clock.call)
        target.save!
        target
      end
      Audit.emit("organization.lifecycle_changed", outcome: "succeeded", operation: organization.status)
      organization
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    rescue StandardError => error
      Audit.emit(
        "organization.lifecycle_rejected",
        outcome: "denied",
        operation: "transition",
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : nil
      )
      raise
    end

    private

    def authorize_owner!(membership, organization)
      valid = membership.active? && OrganizationOwnership.where(
        organization_id: organization.id,
        membership_id: membership.id,
        ended_at: nil
      ).exists?
      raise OrganizationAccessDenied unless valid
    end

    def apply_transition(organization, destination, now)
      organization.status = destination
      case destination
      when "active"
        organization.suspended_at = nil
      when "suspended"
        organization.suspended_at = now
      when "pending_deletion"
        organization.deletion_requested_at = now
      when "deleted"
        organization.deleted_at = now
      end
    end
  end
end
