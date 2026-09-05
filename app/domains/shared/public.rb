# frozen_string_literal: true

module Shared
  module Public
    AuthenticationError = Errors::AuthenticationError
    AuthorizationError = Errors::AuthorizationError
    ConflictError = Errors::ConflictError
    EntitlementError = Errors::EntitlementError
    ExternalProviderError = Errors::ExternalProviderError
    QuotaError = Errors::QuotaError
    RateLimitError = Errors::RateLimitError
    TransientInfrastructureError = Errors::TransientInfrastructureError
    ValidationError = Errors::ValidationError
    NetworkSafetyError = NetworkSafety::Error
    TransientJobError = JobErrors::TransientInfrastructure
    CanceledJobError = JobErrors::Canceled
    SecurityRejectedJobError = JobErrors::SecurityRejected
    FILTERED_VALUE = Redaction::FILTERED

    module_function

    def observability_context
      Observability::Context.snapshot
    end

    def application_uuid?(value)
      Observability::Context::RESOURCE_ID_PATTERN.match?(value.to_s)
    end

    def safe_http_client(dns_timeout:, open_timeout:, read_timeout:, max_response_bytes:, max_redirects:)
      NetworkSafety::SafeHttpClient.new(
        resolver: NetworkSafety::PublicResolver.new(timeout: dns_timeout),
        open_timeout: open_timeout,
        read_timeout: read_timeout,
        max_response_bytes: max_response_bytes,
        max_redirects: max_redirects
      )
    end

    def http_target(url:)
      NetworkSafety::HttpTarget.new(url: url)
    end

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

    def with_tenant_audit(organization_id:, actor_id:, subject_id:, &block)
      Observability::Context.with_tenant_audit(
        organization_id: organization_id,
        actor_id: actor_id,
        subject_id: subject_id,
        &block
      )
    end

    def with_authorization_audit(**attributes, &block)
      Observability::Context.with_authorization_audit(**attributes, &block)
    end

    def with_authorization_decision(**attributes, &block)
      Observability::Context.with_authorization_decision(**attributes, &block)
    end

    def record_outbox_event!(**attributes)
      Events::Public.record!(**attributes)
    end

    def publish_outbox_event!(**attributes)
      Events::Public.publish!(**attributes)
    end

    def enqueue_outbox_event!(outbox_event_id:)
      Events::OutboxPublishJob.perform_later(outbox_event_id: outbox_event_id)
    end

    def unpublished_outbox_event_id(aggregate_type:, aggregate_id:, event_type:)
      Events::OutboxEvent.unpublished.find_by(
        aggregate_type: aggregate_type,
        aggregate_id: aggregate_id,
        event_type: event_type
      )&.id
    end
  end
end
