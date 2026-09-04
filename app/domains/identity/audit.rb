# frozen_string_literal: true

module Identity
  module Audit
    module_function

    def emit(event_name, outcome:, reason_code: nil, provider: nil, operation: nil,
      error_category: nil, actor_user_id: nil, target_type: nil, target_id: nil,
      metadata: {})
      if actor_user_id
        Auditing::Public.record!(
          actor_user_id: actor_user_id,
          action: event_name,
          target_type: target_type || "User",
          target_id: target_id || actor_user_id,
          result: outcome,
          metadata: metadata.merge(
            operation: operation,
            reason_code: reason_code,
            provider: provider
          ).compact
        )
      end
      emit_structured(
        event_name,
        outcome: outcome,
        reason_code: reason_code,
        provider: provider,
        operation: operation,
        error_category: error_category
      )
    end

    def emit_structured(event_name, **attributes)
      Shared::Public.emit_structured_event(event_name, **attributes)
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: event_name)
      nil
    end
    private_class_method :emit_structured
  end
end
