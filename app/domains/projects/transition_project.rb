# frozen_string_literal: true

module Projects
  class TransitionProject
    OPERATIONS = %w[archive reactivate request_deletion cancel_deletion].freeze

    def initialize(clock: -> { Time.current }, authorization: ProjectAuthorization.new,
      limit: ProjectLimit.new)
      @clock = clock
      @authorization = authorization
      @limit = limit
    end

    def call(actor_membership:, project_id:, operation:, deletion_workflow_id: nil,
      current_session: nil, user_id: nil)
      action = operation.to_s
      raise ProjectTransitionInvalid unless OPERATIONS.include?(action)

      result = nil
      outbox_event = Project.transaction do
        project = locked_project!(actor_membership, project_id)
        verify_recent_deletion_authentication!(actor_membership, action, current_session, user_id)
        access = @authorization.authorize!(
          actor_membership: actor_membership,
          permission_key: permission_for(action),
          project: project
        )
        result = transition(project, action, deletion_workflow_id: deletion_workflow_id, at: @clock.call)
        record_transition!(result, access, action)
      end
      ProjectEvent.enqueue(outbox_event) if outbox_event
      result
    end

    private

    def transition(project, operation, deletion_workflow_id:, at:)
      case operation
      when "archive" then archive(project, at)
      when "reactivate" then reactivate(project, at)
      when "request_deletion" then request_deletion(project, deletion_workflow_id, at)
      when "cancel_deletion" then cancel_deletion(project, deletion_workflow_id)
      end
    end

    def archive(project, at)
      return ProjectChangeResult.new(project: project, changed: false) if project.archived?
      raise ProjectTransitionInvalid unless project.active?

      project.update!(
        status: "archived",
        archived_at: at,
        work_cancellation_cutoff_at: at
      )
      register_scope(project, status: "archived", archived_at: at)
      ProjectChangeResult.new(project: project, changed: true)
    end

    def reactivate(project, at)
      return ProjectChangeResult.new(project: project, changed: false) if project.active?
      raise ProjectTransitionInvalid unless project.archived?

      @limit.lock_and_check!(organization_id: project.organization_id, excluding_project_id: project.id, at: at)
      project.update!(status: "active", archived_at: nil, deletion_requested_at: nil)
      register_scope(project, status: "active", archived_at: nil)
      ProjectChangeResult.new(project: project, changed: true)
    end

    def request_deletion(project, deletion_workflow_id, at)
      if project.pending_deletion?
        raise ProjectTransitionInvalid unless project.deletion_workflow_id == deletion_workflow_id

        return ProjectChangeResult.new(project: project, changed: false)
      end
      raise ProjectTransitionInvalid unless project.active? || project.archived?
      raise ProjectTransitionInvalid unless Shared::Public.application_uuid?(deletion_workflow_id)

      archived_at = project.archived_at || at
      project.update!(
        status: "pending_deletion",
        archived_at: archived_at,
        deletion_requested_at: at,
        deletion_workflow_id: deletion_workflow_id,
        work_cancellation_cutoff_at: at
      )
      register_scope(project, status: "archived", archived_at: archived_at)
      ProjectChangeResult.new(project: project, changed: true)
    end

    def cancel_deletion(project, deletion_workflow_id)
      raise ProjectTransitionInvalid unless project.pending_deletion? &&
        project.deletion_workflow_id == deletion_workflow_id

      project.update!(
        status: "archived",
        deletion_requested_at: nil,
        deletion_workflow_id: nil
      )
      ProjectChangeResult.new(project: project, changed: true)
    end

    def record_transition!(result, access, operation)
      event_type = "project.#{event_suffix(operation)}"
      ProjectAudit.record!(
        action: result.changed? ? event_type : "project.lifecycle_ignored",
        actor_membership_id: access.authorization.actor_membership_id,
        organization_id: result.project.organization_id,
        project_id: result.project.id,
        operation: operation,
        metadata: { "status" => result.project.status }
      )
      return unless result.changed?

      ProjectEvent.record!(
        project: result.project,
        event_type: event_type,
        occurred_at: @clock.call,
        actor_membership_id: access.authorization.actor_membership_id
      )
    end

    def event_suffix(operation)
      {
        "archive" => "archived",
        "reactivate" => "reactivated",
        "request_deletion" => "deletion_requested",
        "cancel_deletion" => "deletion_canceled"
      }.fetch(operation)
    end

    def permission_for(operation)
      operation.in?(%w[request_deletion cancel_deletion]) ? "projects.delete" : "projects.archive"
    end

    def register_scope(project, status:, archived_at:)
      Authorization::Public.register_scope(
        organization_id: project.organization_id,
        scope_type: "Project",
        scope_id: project.id,
        status: status,
        archived_at: archived_at
      )
    end

    def locked_project!(actor_membership, project_id)
      Project.lock.find_by!(id: project_id, organization_id: actor_membership&.organization_id)
    rescue ActiveRecord::RecordNotFound
      raise ProjectAccessDenied, cause: nil
    end

    def verify_recent_deletion_authentication!(actor_membership, operation, current_session, user_id)
      return unless operation == "request_deletion"

      membership = Tenancy::Public.authorization_membership(
        organization_id: actor_membership&.organization_id,
        membership_id: actor_membership&.id
      )
      raise ProjectAccessDenied unless membership&.active? && membership.user_id == user_id.to_s

      Identity::Public.verify_recent_session!(
        session: current_session,
        user_id: membership.user_id,
        clock: @clock
      )
    end
  end
end
