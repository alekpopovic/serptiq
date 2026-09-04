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
  end
end
