# frozen_string_literal: true

module Billing
  class WebhookRackEndpoint
    class_attribute :receiver_builder, default: -> { ReceiveWebhook.from_settings }

    RESPONSE_HEADERS = {
      "cache-control" => "no-store",
      "content-length" => "0",
      "referrer-policy" => "no-referrer"
    }.freeze

    def initialize(body_reader: BoundedWebhookBody.new, instrumentation: WebhookIngressInstrumentation.new)
      @body_reader = body_reader
      @instrumentation = instrumentation
    end

    def call(environment)
      request = ActionDispatch::Request.new(environment)
      raw_body = @body_reader.call(io: request.body, content_length: request.content_length)
      receipt = self.class.receiver_builder.call.call(raw_body: raw_body, headers: webhook_headers(request))
      return respond(409, "conflicting_duplicate") if receipt.status == "conflict"

      respond(200, receipt.status)
    rescue WebhookBodyTooLarge
      respond(413, "body_too_large")
    rescue WebhookMediaTypeUnsupported
      respond(415, "media_type_unsupported")
    rescue ProviderFailure => error
      error.category == "signature_invalid" ? respond(401, "signature_invalid") : respond(422, "payload_invalid")
    rescue WebhookEnqueueFailure
      respond(503, "enqueue_unavailable")
    rescue ArgumentError
      respond(422, "payload_invalid")
    rescue StandardError => error
      Rails.error.report(error, handled: true, severity: :error, context: { "operation" => "receive_webhook" })
      respond(500, "internal_failure")
    end

    private

    def webhook_headers(request)
      {
        "content-type" => request.get_header("CONTENT_TYPE"),
        "content-length" => request.get_header("CONTENT_LENGTH"),
        "user-agent" => request.get_header("HTTP_USER_AGENT"),
        "x-signature" => request.get_header("HTTP_X_SIGNATURE")
      }.compact.freeze
    end

    def respond(status, reason_code)
      outcome = status == 200 ? "succeeded" : "denied"
      @instrumentation.emit(outcome: outcome, reason_code: reason_code, http_status: status)
      [ status, RESPONSE_HEADERS.dup, [] ]
    end
  end
end
