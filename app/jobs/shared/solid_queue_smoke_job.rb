# frozen_string_literal: true

module Shared
  class SolidQueueSmokeJob < ApplicationJob
    runs_on :maintenance
    system_authorization :solid_queue_smoke,
      reason: "performs a side-effect-free infrastructure execution check"

    def perform
      # Intentionally side-effect free. A finished Solid Queue record proves
      # that serialization, PostgreSQL claiming and Active Job execution work.
    end
  end
end
