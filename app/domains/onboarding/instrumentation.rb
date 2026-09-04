# frozen_string_literal: true

module Onboarding
  module Instrumentation
    module_function

    def started
      emit("onboarding.started", operation: "start")
    end

    def step_completed(step)
      emit("onboarding.step_completed", operation: step)
    end

    def abandoned(step)
      emit("onboarding.abandoned", operation: step, outcome: "ignored")
    end

    def completed
      emit("onboarding.completed", operation: "complete")
    end

    def emit(event_name, operation:, outcome: "succeeded")
      Shared::Public.emit_structured_event(event_name, operation: operation, outcome: outcome)
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: event_name)
    end
  end
end
