# frozen_string_literal: true

module Crawling
  module ScanTransitionMatrix
    TRANSITIONS = {
      "admit" => { "requested" => "admitted" },
      "queue" => { "admitted" => "queued" },
      "start" => { "queued" => "running" },
      "acknowledge_cancel" => { "cancel_requested" => "canceled" },
      "complete" => { "running" => "completed" },
      "complete_partially" => { "running" => "partially_completed" },
      "fail" => Scan::STATUSES.index_with { "failed" }.except(*Scan::TERMINAL_STATUSES)
    }.freeze
    CANCELLATION_TRANSITIONS = {
      "requested" => "canceled",
      "admitted" => "canceled",
      "queued" => "cancel_requested",
      "running" => "cancel_requested"
    }.freeze

    module_function

    def target(status:, command:)
      TRANSITIONS.fetch(command.to_s, {}).fetch(status.to_s, nil)
    end

    def allowed?(status:, command:)
      target(status: status, command: command).present?
    end

    def cancellation_target(status:)
      CANCELLATION_TRANSITIONS[status.to_s]
    end

    def commands
      TRANSITIONS.keys.freeze
    end
  end
end
