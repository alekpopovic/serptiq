class ApplicationController < ActionController::Base
  rescue_from StandardError, with: :render_public_error

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def render_public_error(error)
    mapping = Shared::Errors.http_response_for(error)
    record_public_error(error, mapping)
    response.set_header("X-SearchOps-Error-Code", mapping.public_code)

    payload = {
      code: mapping.public_code,
      message: mapping.public_message,
      request_id: Shared::Observability::Context.request_id || request.request_id
    }.compact

    if request.format.json?
      render json: { error: payload }, status: mapping.http_status
    else
      render template: "errors/show", locals: { error: payload }, status: mapping.http_status
    end
  end

  def record_public_error(error, mapping)
    cause_classes = Shared::Errors.cause_classes(error)
    reason_code = error.reason_code if error.respond_to?(:reason_code)
    emit_public_error(error, mapping, reason_code, cause_classes)

    return if mapping.expected && cause_classes.empty?

    Rails.error.report(
      error,
      handled: true,
      severity: mapping.expected ? :warning : :error,
      context: Shared::Observability::Context.snapshot.merge("public_error_code" => mapping.public_code)
    )
  end

  def emit_public_error(error, mapping, reason_code, cause_classes)
    Shared::Observability.emitter.emit(
      "http.request_failed",
      severity: mapping.expected ? :warn : :error,
      outcome: mapping.expected ? "denied" : "failed",
      error_category: mapping.category,
      error_code: mapping.public_code,
      reason_code: reason_code,
      http_status: mapping.http_status,
      exception_class: error.class.name.presence || "AnonymousError",
      cause_classes: cause_classes.presence
    )
  rescue StandardError => observability_error
    Rails.error.report(
      observability_error,
      handled: true,
      severity: :warning,
      context: Shared::Observability::Context.snapshot.merge("failed_event" => "http.request_failed")
    )
  end
end
