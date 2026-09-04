# frozen_string_literal: true

module Tenancy
  class ManageTeam
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def create(actor_membership:, name:, authorization: nil)
      team = Team.transaction do
        organization = lock_organization(actor_membership, authorization)
        Team.create!(organization: organization, name: name, status: "active")
      end
      emit("team.created", "create", actor_membership, team.id)
      team
    rescue StandardError => error
      reject("create", actor_membership, nil, error)
      raise
    end

    def rename(actor_membership:, team_id:, name:, authorization: nil)
      team = Team.transaction do
        team = lock_active_team(actor_membership, team_id, authorization)
        team.update!(name: name)
        team
      end
      emit("team.renamed", "rename", actor_membership, team.id)
      team
    rescue StandardError => error
      reject("rename", actor_membership, team_id, error)
      raise
    end

    def archive(actor_membership:, team_id:, authorization: nil)
      result = Team.transaction do
        organization = lock_organization(actor_membership, authorization)
        team = Team.lock.find_by!(id: team_id, organization_id: organization.id)
        if team.archived?
          TeamChangeResult.new(record: team, changed: false)
        else
          team.update!(status: "archived", archived_at: @clock.call)
          TeamChangeResult.new(record: team, changed: true)
        end
      end
      emit("team.archived", result.changed? ? "archive" : "archive_ignored", actor_membership, result.record.id)
      result
    rescue StandardError => error
      public_error = error.is_a?(ActiveRecord::RecordNotFound) ? OrganizationAccessDenied.new : error
      reject("archive", actor_membership, team_id, public_error)
      raise public_error, cause: nil if public_error != error

      raise
    end

    private

    def lock_organization(actor, authorization)
      state = OwnerInvariant.new.lock!(organization_id: actor&.organization_id)
      organization = state.organization
      AuthorizeMembershipAccess.new.call(
        membership: actor, permission_key: "teams.manage", authorization: authorization
      )
      organization
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end

    def lock_active_team(actor, team_id, authorization)
      organization = lock_organization(actor, authorization)
      team = Team.lock.find_by!(id: team_id, organization_id: organization.id)
      raise InvalidOrganizationTransition.new(reason_code: "team_archived") unless team.active?

      team
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end

    def emit(event, operation, actor, subject)
      Audit.emit(event, outcome: "succeeded", operation: operation,
        actor_membership_id: actor.id, subject_membership_id: subject)
    end

    def reject(operation, actor, subject, error)
      Audit.emit("team.change_rejected", outcome: "denied", operation: operation,
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : nil,
        actor_membership_id: actor&.id, subject_membership_id: subject)
    end
  end
end
