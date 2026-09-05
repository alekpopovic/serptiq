# frozen_string_literal: true

module Crawling
  class MeteredHttpRequestObserver
    def initialize(context:, meter: HttpFetchUsageMeter.new)
      @context = context
      @meter = meter
    end

    def before_request(sequence:)
      operation = @meter.start(context: @context, sequence: sequence)
      return operation unless operation.is_a?(HttpFetchUsageMeter::Denied)

      raise Shared::Public::NetworkSafetyError.new(
        reason_code: operation.reason_code,
        evidence: { denial_stage: "quota" }
      )
    end

    def after_response(sequence:, operation:, **)
      @meter.finish(
        context: @context,
        sequence: sequence,
        operation: operation,
        outcome: "accepted"
      )
    end

    def after_failure(sequence:, operation:, reason_code:)
      @meter.finish(
        context: @context,
        sequence: sequence,
        operation: operation,
        outcome: failure_outcome(reason_code)
      )
    end

    private

    def failure_outcome(reason_code)
      return "canceled" if reason_code.to_s.in?(%w[canceled scan_canceled])
      return "rejected" if HttpFetcher::REJECTED_ERRORS.include?(reason_code.to_s)

      "failed"
    end
  end
end
