# frozen_string_literal: true

class OperationalStatusController < ActionController::API
  class_attribute :readiness_checker, default: Shared::OperationalReadiness

  before_action :disable_caching

  def up
    render json: { status: "up" }
  end

  def ready
    result = self.class.readiness_checker.call(
      role: Rails.application.config.x.searchops.fetch(:process_role)
    )
    render json: result.public_payload, status: result.ready? ? :ok : :service_unavailable
  end

  def version
    render json: Shared::ReleaseInformation.call
  end

  private

  def disable_caching
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end
end
