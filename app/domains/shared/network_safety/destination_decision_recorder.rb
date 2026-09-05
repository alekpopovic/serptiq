# frozen_string_literal: true

module Shared
  module NetworkSafety
    class DestinationDecisionRecorder
      def initialize(emitter: -> { Observability.emitter })
        @emitter = emitter
      end

      def call(outcome:, reason_code:, evidence:)
        return unless outcome.to_s == "denied"

        safe = Error.new(reason_code: reason_code, evidence: evidence).evidence
        emitter.emit(
          "crawler.destination_rejected",
          severity: :warn,
          outcome: "denied",
          operation: safe.fetch(:denial_stage, "destination_policy"),
          reason_code: reason_code,
          **safe.slice(
            :address_count,
            :ipv4_address_count,
            :ipv6_address_count,
            :destination_port,
            :address_policy_version
          )
        )
      rescue StandardError => error
        Rails.error.report(
          error,
          handled: true,
          severity: :warning,
          context: { "failed_event" => "crawler.destination_rejected" }
        )
      end

      private

      def emitter
        @emitter.respond_to?(:call) ? @emitter.call : @emitter
      end
    end
  end
end
