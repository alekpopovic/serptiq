# frozen_string_literal: true

module Shared
  module Observability
    class JobContext
      def initialize(runtime_attributes: nil, emitter: nil)
        @runtime_attributes = runtime_attributes
        @emitter = emitter
      end

      def call(job)
        Context.reset
        job_id = Context.normalize_correlation_id(job.job_id, fallback: "unknown-job")
        trace_id = Context.normalize_correlation_id(job.observability_trace_id, fallback: job_id)
        Context.set(runtime_attributes.merge(job_id: job_id, trace_id: trace_id)) do
          yield
        rescue StandardError => error
          safely_emit_failure(job, error)
          raise
        end
      ensure
        Context.reset
      end

      private

      def runtime_attributes
        @runtime_attributes || Observability.runtime_attributes
      end

      def emit_failure(job, error)
        response = Shared::Errors.http_response_for(error)
        (@emitter || Observability.emitter).emit(
          "job.execution_failed",
          severity: :error,
          outcome: "failed",
          error_category: response.category,
          error_code: response.public_code,
          retry_count: job.executions,
          exception_class: error.class.name.presence || "AnonymousError",
          cause_classes: Shared::Errors.cause_classes(error).presence
        )
      end

      def safely_emit_failure(job, error)
        emit_failure(job, error)
      rescue StandardError => observability_error
        Rails.error.report(
          observability_error,
          handled: true,
          severity: :warning,
          context: Context.snapshot.merge("failed_event" => "job.execution_failed")
        )
      end
    end
  end
end
