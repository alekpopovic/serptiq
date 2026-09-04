# frozen_string_literal: true

module Shared
  module Public
    AuthenticationError = Errors::AuthenticationError
    AuthorizationError = Errors::AuthorizationError
    ConflictError = Errors::ConflictError
    ExternalProviderError = Errors::ExternalProviderError
    RateLimitError = Errors::RateLimitError
    ValidationError = Errors::ValidationError

    module_function

    def emit_structured_event(event_name, **attributes)
      Observability.emitter.emit(event_name, **attributes)
    end

    def report_observability_failure(error, event_name:)
      Rails.error.report(
        error,
        handled: true,
        severity: :warning,
        context: Observability::Context.snapshot.merge("failed_event" => event_name)
      )
    end

    def with_audit_principals(actor_id:, subject_id:, &block)
      Observability::Context.with_audit_principals(actor_id: actor_id, subject_id: subject_id, &block)
    end

    def with_authorization_audit(**attributes, &block)
      Observability::Context.with_authorization_audit(**attributes, &block)
    end

    def with_authorization_decision(**attributes, &block)
      Observability::Context.with_authorization_decision(**attributes, &block)
    end
  end
end
