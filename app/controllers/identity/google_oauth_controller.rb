# frozen_string_literal: true

module Identity
  class GoogleOauthController < ApplicationController
    class_attribute :authorization_starter_factory,
      instance_accessor: false,
      default: -> { GoogleAuthorizationStarter.from_settings }

    before_action :set_sensitive_response_headers

    def create
      start = self.class.authorization_starter_factory.call.call(
        return_to: SafeReturnPath.call(params[:return_to]),
        link_intent: parse_link_intent(params[:link]),
        current_session: Current.session,
        initiator_digest: OauthInitiator.from_request(request).digest
      )
      # `redirect_to` publishes the complete destination to Rails redirect logs.
      # This trusted value contains one-time state/nonce query parameters, so set
      # the header directly after the adapter's exact-host validation.
      response.set_header("Location", start.authorization_request.to_s)
      head :see_other
    end

    def callback
      raise ProviderError.new(
        category: "configuration",
        operation: "callback_exchange",
        reason_code: "google_callback_not_implemented"
      )
    end

    private

    def parse_link_intent(value)
      return false if value.nil? || value == false || value == "0"
      return true if value == true || value == "1"

      raise InvalidOauthInitiation
    end

    def set_sensitive_response_headers
      response.headers["Cache-Control"] = "no-store, max-age=0"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Content-Type-Options"] = "nosniff"
      response.headers["X-Frame-Options"] = "DENY"
    end
  end
end
