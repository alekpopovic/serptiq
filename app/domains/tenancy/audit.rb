# frozen_string_literal: true

module Tenancy
  module Audit
    module_function

    def emit(event_name, outcome:, operation:, reason_code: nil, actor_membership_id: nil,
      subject_membership_id: nil, organization_id: nil, target_type: nil, target_id: nil,
      metadata: {}, severity: :info)
      organization_id ||= organization_for(actor_membership_id, subject_membership_id)
      target_type ||= infer_target_type(event_name)
      target_id ||= inferred_target_id(target_type, organization_id, subject_membership_id)
      Auditing::Public.record!(
        organization_id: organization_id,
        actor_membership_id: actor_membership_id,
        action: event_name,
        target_type: target_type,
        target_id: target_id,
        result: outcome,
        metadata: metadata.merge(operation: operation, reason_code: reason_code).compact
      )
      emit_structured(
        event_name,
        organization_id: organization_id,
        actor_membership_id: actor_membership_id,
        subject_membership_id: subject_membership_id,
        outcome: outcome,
        operation: operation,
        reason_code: reason_code,
        severity: severity
      )
    end

    def emit_structured(event_name, organization_id:, actor_membership_id:, subject_membership_id:,
      outcome:, operation:, reason_code:, severity:)
      Shared::Public.with_tenant_audit(
        organization_id: organization_id,
        actor_id: actor_membership_id,
        subject_id: subject_membership_id
      ) do
        Shared::Public.emit_structured_event(
          event_name,
          severity: severity,
          outcome: outcome,
          operation: operation,
          reason_code: reason_code
        )
      end
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: event_name)
      nil
    end
    private_class_method :emit_structured

    def organization_for(actor_id, subject_id)
      Membership.where(id: actor_id || subject_id).pick(:organization_id)
    end
    private_class_method :organization_for

    def infer_target_type(event_name)
      case event_name
      when /\Aorganization\.ownership_/ then "Membership"
      when /\Aorganization\./ then "Organization"
      when /\Amembership\./ then "Membership"
      when /\Ainvitation\./ then "Invitation"
      when /\Ateam\.member/ then "Membership"
      when /\Ateam\./ then "Team"
      else "Organization"
      end
    end
    private_class_method :infer_target_type

    def inferred_target_id(target_type, organization_id, subject_id)
      target_type == "Organization" ? organization_id : subject_id
    end
    private_class_method :inferred_target_id
  end
end
