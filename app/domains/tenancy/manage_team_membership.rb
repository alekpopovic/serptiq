# frozen_string_literal: true

module Tenancy
  class ManageTeamMembership
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def add(actor_membership:, team_id:, membership_id:, authorization: nil)
      result = TeamMembership.transaction do
        actor, team = lock_context(actor_membership, team_id, authorization)
        target = Membership.lock.find_by!(id: membership_id, organization_id: team.organization_id)
        raise OrganizationAccessDenied.new(reason_code: "membership_inactive") unless target.active?

        existing = TeamMembership.find_by(team_id: team.id, membership_id: target.id, removed_at: nil)
        if existing
          TeamChangeResult.new(record: existing, changed: false)
        else
          record = TeamMembership.create!(
            organization_id: team.organization_id,
            team: team,
            membership: target,
            added_by_membership: actor,
            added_at: @clock.call
          )
          TeamChangeResult.new(record: record, changed: true)
        end
      end
      emit("team.member_added", result.changed? ? "add" : "add_ignored", actor_membership, membership_id)
      result
    rescue ActiveRecord::RecordNotUnique
      retry_result(actor_membership, team_id, membership_id)
    rescue StandardError => error
      public_error = error.is_a?(ActiveRecord::RecordNotFound) ? OrganizationAccessDenied.new : error
      reject("add", actor_membership, membership_id, public_error)
      raise public_error, cause: nil if public_error != error

      raise
    end

    def remove(actor_membership:, team_id:, membership_id:, authorization: nil)
      result = TeamMembership.transaction do
        _, team = lock_context(actor_membership, team_id, authorization)
        Membership.find_by!(id: membership_id, organization_id: team.organization_id)
        record = TeamMembership.lock.find_by(team_id: team.id, membership_id: membership_id, removed_at: nil)
        if record
          record.update!(removed_at: @clock.call)
          TeamChangeResult.new(record: record, changed: true)
        else
          TeamChangeResult.new(record: nil, changed: false)
        end
      end
      emit("team.member_removed", result.changed? ? "remove" : "remove_ignored", actor_membership, membership_id)
      result
    rescue StandardError => error
      public_error = error.is_a?(ActiveRecord::RecordNotFound) ? OrganizationAccessDenied.new : error
      reject("remove", actor_membership, membership_id, public_error)
      raise public_error, cause: nil if public_error != error

      raise
    end

    private

    def lock_context(actor, team_id, authorization)
      raise OrganizationAccessDenied unless actor.is_a?(Membership)

      locked_actor = Membership.lock.find(actor.id)
      organization = Organization.lock.find(locked_actor.organization_id)
      AuthorizeMembershipAccess.new.call(
        membership: locked_actor, permission_key: "teams.manage", authorization: authorization
      )
      team = Team.lock.find_by!(id: team_id, organization_id: organization.id)
      raise InvalidOrganizationTransition.new(reason_code: "team_archived") unless team.active?

      [ locked_actor, team ]
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end

    def retry_result(actor, team_id, membership_id)
      record = TeamMembership.find_by!(team_id: team_id, membership_id: membership_id, removed_at: nil)
      result = TeamChangeResult.new(record: record, changed: false)
      emit("team.member_added", "add_ignored", actor_membership, membership_id)
      result
    rescue ActiveRecord::RecordNotFound
      raise MembershipAlreadyExists.new(reason_code: "team_membership_conflict"), cause: nil
    end

    def emit(event, operation, actor, subject)
      Audit.emit(event, outcome: "succeeded", operation: operation,
        actor_membership_id: actor.id, subject_membership_id: subject)
    end

    def reject(operation, actor, subject, error)
      Audit.emit("team.membership_rejected", outcome: "denied", operation: operation,
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : nil,
        actor_membership_id: actor&.id, subject_membership_id: subject)
    end
  end
end
