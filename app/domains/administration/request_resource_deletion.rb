# frozen_string_literal: true

module Administration
  class RequestResourceDeletion
    GRACE_PERIOD = 30.days

    def initialize(clock: -> { Time.current }, grace_period: GRACE_PERIOD)
      @clock = clock
      @grace_period = grace_period
    end

    def call(actor_membership:, target_type:, project_id:, property_id: nil, current_session:, user_id:)
      type = normalize_target_type(target_type)
      validate_target_ids!(type, project_id, property_id)
      now = @clock.call
      workflow = DeletionWorkflow.transaction do
        lock_resource_tree!(actor_membership&.organization_id, project_id)
        existing = active_workflow(
          organization_id: actor_membership&.organization_id,
          target_type: type,
          target_id: target_id(type, project_id, property_id)
        )
        if existing
          verify_existing_request!(
            actor_membership: actor_membership,
            workflow: existing,
            current_session: current_session,
            user_id: user_id,
            now: now
          )
          existing
        else
          create_and_transition!(
            actor_membership: actor_membership,
            target_type: type,
            project_id: project_id,
            property_id: property_id,
            current_session: current_session,
            user_id: user_id,
            now: now
          )
        end
      end
      enqueue(workflow)
      workflow
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    private

    def lock_resource_tree!(organization_id, project_id)
      key = "resource-deletion:#{organization_id}:#{project_id}"
      connection = DeletionWorkflow.connection
      connection.execute(
        "SELECT pg_advisory_xact_lock(hashtextextended(#{connection.quote(key)}, 0))"
      )
    end

    def create_and_transition!(actor_membership:, target_type:, project_id:, property_id:,
      current_session:, user_id:, now:)
      reconcile_descendant_workflows!(
        actor_membership: actor_membership,
        target_type: target_type,
        project_id: project_id,
        now: now
      )
      workflow = DeletionWorkflow.create!(
        organization_id: actor_membership&.organization_id,
        target_type: target_type,
        target_id: target_id(target_type, project_id, property_id),
        project_id: project_id,
        property_id: property_id,
        requested_by_membership_id: actor_membership&.id,
        state: "holding",
        requested_at: now,
        hold_until: now + @grace_period
      )
      DeletionWorkflow::STAGES.each_with_index do |stage, position|
        workflow.stage_executions.create!(
          organization_id: workflow.organization_id,
          stage: stage,
          position: position
        )
      end
      transition_target!(
        actor_membership: actor_membership,
        workflow: workflow,
        current_session: current_session,
        user_id: user_id,
        operation: "request_deletion"
      )
      workflow
    end

    def reconcile_descendant_workflows!(actor_membership:, target_type:, project_id:, now:)
      return unless target_type == "Project"

      descendants = DeletionWorkflow.active.lock.where(
        organization_id: actor_membership&.organization_id,
        target_type: "Property",
        project_id: project_id
      ).order(:id).to_a
      raise DeletionConflict.new(reason_code: "descendant_deletion_in_progress") if
        descendants.any? { |workflow| !workflow.cancelable?(at: now) }

      descendants.each do |workflow|
        CancelResourceDeletion.new(clock: -> { now }).call(
          actor_membership: actor_membership,
          target_type: "Property",
          project_id: project_id,
          property_id: workflow.property_id
        )
      end
    end

    def verify_existing_request!(actor_membership:, workflow:, current_session:, user_id:, now:)
      transition_target!(
        actor_membership: actor_membership,
        workflow: workflow,
        current_session: current_session,
        user_id: user_id,
        operation: "request_deletion",
        clock: -> { now }
      )
    end

    def transition_target!(actor_membership:, workflow:, current_session:, user_id:, operation:, clock: @clock)
      attributes = {
        actor_membership: actor_membership,
        project_id: workflow.project_id,
        operation: operation,
        deletion_workflow_id: workflow.id,
        current_session: current_session,
        user_id: user_id,
        clock: clock
      }
      if workflow.target_type == "Project"
        Projects::Public.transition_project(**attributes)
      else
        Properties::Public.transition_property(**attributes, property_id: workflow.property_id)
      end
    end

    def active_workflow(organization_id:, target_type:, target_id:)
      DeletionWorkflow.active.lock.find_by(
        organization_id: organization_id,
        target_type: target_type,
        target_id: target_id
      )
    end

    def target_id(target_type, project_id, property_id)
      target_type == "Project" ? project_id : property_id
    end

    def normalize_target_type(value)
      value.to_s.tap do |type|
        raise ArgumentError, "unsupported deletion target" unless DeletionWorkflow::TARGET_TYPES.include?(type)
      end
    end

    def validate_target_ids!(target_type, project_id, property_id)
      valid = Shared::Public.application_uuid?(project_id)
      valid &&= property_id.nil? if target_type == "Project"
      valid &&= Shared::Public.application_uuid?(property_id) if target_type == "Property"
      raise ArgumentError, "deletion target is invalid" unless valid
    end

    def enqueue(workflow)
      DeletionWorkflowJob.set(wait_until: workflow.hold_until).perform_later(
        organization_id: workflow.organization_id,
        workflow_id: workflow.id
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "data.deletion_enqueue_failed")
    end
  end
end
